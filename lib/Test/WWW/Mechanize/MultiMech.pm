package Test::WWW::Mechanize::MultiMech;

use 5.006;
use strict;
use warnings FATAL => 'all';
our $VERSION = '1.001';
use Test::WWW::Mechanize;
use Test::Builder qw//;
use Carp qw/croak/;

sub _diag {
    Test::Builder->new->diag(@_);
}

sub new {
    my ( $class, %args ) = @_;

    ref $args{users} eq 'ARRAY'
        or croak 'You must give ``users\'\' to new->new(); '
                . 'and it needs to be an arrayref';

    my @args_users = @{ delete $args{users} };
    my ( %users, @users_order );
    for ( grep !($_%2), 0 .. $#args_users ) {
        my $user_args = $args_users[ $_+1 ];

        push @users_order, $args_users[ $_ ];

        my $mech = Test::WWW::Mechanize->new( %args );
        $users{ $args_users[$_] } = {
            login   => (
                defined $user_args->{login}
                ? $user_args->{login} : $args_users[ $_ ]
            ),
            pass    => $user_args->{pass},
            mech    => $mech,
        };
    }

    my $self = bless {}, $class;
    $self->{USERS}       = \%users;
    $self->{USERS_ORDER} = \@users_order;
    $self->{MECH_ARGS}   = \%args;
    return $self;
}

sub _mech {
    my $self = shift;
    return $self->{USERS}{ $self->{USERS_ORDER}[0] }{mech};
}

sub _all_mechs {
    my $self = shift;
    return map $_->{mech}, @{ $self->{USERS} };
}

sub login {
    my ( $self, %args ) = @_;

    my $page = delete $args{login_page};
    eval {
        $page = $self->_mech->uri
            unless defined $page;
    };
    if ( $@ ) {
        croak 'You did not give ->login() a page and mech did not yet'
        . ' access any pages. Cannot proceed further';
    }

    my $users = $self->{USERS};
    my $c = 0;
    for my $alias ( @{$self->{USERS_ORDER}} ) {
        my $mech = $users->{ $alias }{mech};

        $mech->get_ok(
            $page,
            "[$alias] get_ok($page)",
        );

        my $user_args = { %args };
        if ( $user_args->{fields} ) {
            $user_args->{fields} = {%{ $user_args->{fields} }};
        }

        for ( values %{ $user_args->{fields} || {} } ) {
            next unless ref eq 'SCALAR';
            if ( $$_ eq 'LOGIN'   ) { $_ = $users->{ $alias }{login}; }
            elsif ( $$_ eq 'PASS' ) { $_ = $users->{ $alias }{pass};  }
        }

        $mech->submit_form_ok(
            $user_args,
            "[$alias] Submitting login form",
        );
    }
}

sub AUTOLOAD {
    my ( $self, @args ) = @_;

    our $AUTOLOAD;
    my $method = (split /::/, $AUTOLOAD)[-1];
    return if $method eq 'DESTROY';

    if ( $self->_mech->can($method) ) {
        return $self->_call_mech_method_on_each_user( $method, \@args );
    }
    elsif ( grep $_ eq $method, @{ $self->{USERS_ORDER} } ) {
        _diag "[$method]-only call";
        return $self->{USERS}{ $method }{mech};
    }
    elsif ( $method eq 'any' ) {
        _diag "[any] call";
        return $self->_mech;
    }

    croak qq|Can't locate object method "$method" via package |
        . __PACKAGE__;
}

sub _call_mech_method_on_each_user {
    my ( $self, $method, $args ) = @_;

    my %returns;
    for my $alias ( @{$self->{USERS_ORDER}} ) {
        _diag("\n[$alias] Calling ->$method()\n");
        $returns{ $alias }
        = $self->{USERS}{ $alias }{mech}->$method( @$args );
    }

    $returns{any} = (values %returns)[0];
    return \%returns;
}

sub remove_user {
    my ( $self, $login ) = @_;

    return unless exists $self->{USERS}{ $login };

    @{ $self->{USERS_ORDER} }
    = grep $_ ne $login, @{ $self->{USERS_ORDER}  };

    my $args = delete $self->{USERS}{ $login };

    croak 'You must have at least one user and you '
        . 'just removed the last one'
        unless @{ $self->{USERS_ORDER}  };

    return ( $login, $args );
}

sub add_user {
    my ( $self, $login, $args ) = @_;

    my $mech = Test::WWW::Mechanize->new( %{ $self->{MECH_ARGS} } );

    $self->{USERS}{ $login } = {
        %{ $args || {} },
        mech => $mech,
    };

    @{ $self->{USERS_ORDER} } = (
        ( grep $_ ne $login, @{ $self->{USERS_ORDER} } ),
        $login,
    );

    return;
}

sub all_users {
    my $self = shift;
    return @{ $self->{USERS_ORDER} };
}

q|
Why programmers like UNIX: unzip, strip, touch, finger, grep, mount, fsck,
    more, yes, fsck, fsck, fsck, umount, sleep
|;
__END__

=encoding utf8

=head1 NAME

Test::WWW::Mechanize::MultiMech - coordinate multi-object mech tests for multi-user web app testing

=head1 SYNOPSIS

    use strict;
    use warnings;
    use lib qw(lib ../lib);
    use Test::WWW::Mechanize::MultiMech;

    my $mech = Test::WWW::Mechanize::MultiMech->new(
        users   => [
            admin       => { pass => 'adminpass', },
            super       => { pass => 'superpass', },
            clerk       => { pass => 'clerkpass', },
            shipper     => {
                login => 'shipper@system.com',
                pass => 'shipperpass',
            },
        ],
    );

    # optional shortcut method to login all users
    $mech->login(
        login_page => 'http://myapp.com/',
        form_id => 'login_form',
        fields => {
            login => \'LOGIN',
            pass  => \'PASS',
        },
    );

    $mech         ->text_contains('MyApp.com User Interface');  # all users
    $mech->admin  ->text_contains('Administrator Panel');       # only admin
    $mech->shipper->text_lacks('We should not tell shippers about the cake');

    $mech         ->add_user('guest');     # add another user
    $mech         ->get_ok('/user-info');  # get page with each user
    $mech->guest  ->text_contains('You must be logged in to view this page');
    $mech         ->remove_user('guest');  # now, get rid of the guest user

    $mech         ->text_contains('Your user information'  );  # all users
    $mech->admin  ->text_contains('You are an admin user!' );  # admin user only
    $mech->super  ->text_contains('You are a super user!'  );  # super user only
    $mech->clerk  ->text_contains('You are a clerk user!'  );  # clerk user only

    # call ->res once on "any one" mech object
    print $mech->any->res->decoded_content;

    # call ->uri method on every object and inspect value returned for admin user
    print $mech->uri->{admin}->query;

    # call ->uri method on every object and inspect value returned for 'any one' user
    print $mech->uri->{any}->query;

=head1 DESCRIPTION

Ofttimes I had to test a web app where I had several user permission
categories and I needed to ensure that, for example, only admins get
the admin panel, etc. This module allows you to instantiate several
L<Test::WWW::Mechanize> objects and then easily call methods
on all of them (using one line of code) or individually, to test for
differences between them that should be there.

=head1 ORDERING/SIMULTANEITY NOTES

Note that this module does not fork out or do any other business to
make all the mech objects execute their methods B<simultaneously>. The
methods that are called to be executed on all mech objects will be called
in the order that you specify the C<users> to the C<< ->new >> method.
Which user you get when using C<any>—either as a method or the key
in return value hashref—is not specified; it is what it says on the tin,
"any" user.

=head1 GENERAL IDEA BEHIND THE INTERFACE OF THIS MODULE

The general idea is that you define aliases for each of your mech
objects in the bunch inside the C<< ->new >> method. Then, you can call
your usual L<Test::WWW::Mechanize> methods on your
C<Test::WWW::Mechanize::MultiMech> object and they will be called
B<on each> mech object in a bundle. And, you can use the aliases you
specified to call L<Test::WWW::Mechanize> methods on specific objects
in the bundle.

The return value for all-object method calls will be hashrefs, where keys
are the user aliases and values are the return values of the method call
for each user. E.g.:

    $mech->get_ok('http://foo.com/bar');
    $mech->text_contains('Foo');
    print $mech->uri->{user_alias}->query;

If you make a call C<< $mech->USER_ALIAS->method >> that method
will be called B<only> for the user whose alias is C<USER_ALIAS>, e.g.

    # check that "admin" users have Admin panel
    $mech->admin->text_contains('Admin panel');

There's a special user called "C<any>". It exists to allow you to create
tests without reliance on any specific user alias. You can think of it
as picking any user's return value or picking any user's mech object
and sticking with it. E.g.:

    $mech->get_ok('http://foo.com/bar');
    $mech->any->uri->query;  # one call to ->uri using any user's mech object
    # or
    # call ->uri on every mech object and get the result of any one of them
    $mech->uri->{any}->query;

=head1 METHODS

=head2 C<new>

    my $mech = Test::WWW::Mechanize::MultiMech->new(
        users   => [
            user        => { },
            admin       => { pass => 'adminpass',   },
            super       => { pass => 'superpass',   },
            clerk       => { pass => 'clerkpass',   },
            shipper     => {
                login => 'shipper@system.com',
                pass => 'shipperpass',
            },
        ],
    );

You B<must> specify at least one user using the C<users> key, whose
value is an arrayref of users. Everything else will be B<passed> to
the C<< ->new >> method of L<Test::WWW::Mechanize>. The users arrayref
is specified as a list of key/value pairs, where keys are user aliases
and values are—possibly empty—hashrefs of parameters. The aliases will be
used as method calls to call methods on mech object of individual
users (see L<GENERAL IDEA BEHIND THE INTERFACE OF THIS MODULE>
section above), so ensure your user aliases do not conflict with mech
calls and other things (e.g. you can't have a user alias named
C<get_ok>, as calling C<< $mech->get_ok('foo'); >> would call
the C<< ->get_ok >> L<Test::WWW::Mechanize> method on each of your users).
Currently valid keys in the hashref value are:

=head3 C<pass>

    my $mech = Test::WWW::Mechanize::MultiMech->new(
        users   => [
            admin => { pass => 'adminpass', },
        ],
    );

B<Optional>. Specifies user's password, which is currently only used in the
C<< ->login() >> method. B<By default> is not specified.

=head3 C<login>

    my $mech = Test::WWW::Mechanize::MultiMech->new(
        users   => [
            admin => { login => 'joe@example.com' },
        ],
    );

B<Optional>. Specifies user's login (user name), which is currently only used in the C<< ->login() >> method. B<If not specified>, the alias
for this user will be used as login instead (e.g. C<admin> would be
used in the example code above, instead of C<joe@example.com>).

=head2 C<login>

    $mech->login(
        login_page => 'http://myapp.com/',
        form_id => 'login_form',
        fields => {
            login => \'LOGIN',
            pass  => \'PASS',
        },
    );

This is a convenience method designed for logging in each user,
and you don't have to use it.
It's a shortcut for accessing page C<login_page> and then calling
C<< ->submit_form_ok() >> for each user, with login/password set
individually.

Takes arguments as key/value pairs. Value of key C<login_page>
B<specifies> the URL of the login page. B<If omitted>, current page
of each mech object will be used.

All other arguments will be forwarded to the C<< ->submit_form_ok() >>
method of L<Test::WWW::Mechanize>.

The C<fields> argument, if specified, can contain any field name
whose value is C<\'LOGIN'> or C<\'PASS'> (note the reference
operator C<\>). If such fields are specified, their values will be
substituded with the login/password of each user individually.

=head2 C<add_user>

    $mech->add_user('guest');

    $mech->add_user( guest => {
            pass  => 'guestpass',
            login => 'guestuser',
        }
    );

Adds new mech object to the bundle. This can be useful when you
want to do a quick test on a page with an unpriveleged user, whom
you dump with a C<< ->remove_user >> method.
B<Takes> a user alias, optionally followed by user args hashref.
See C<< ->new() >> method for passible keys/values in the user args
hashref. Calling with a user alias alone is equivalent to calling with
an empty user args hashref.

If a user under the given user alias already exists, their user args
hashref will be overwritten. The user alias added with C<< ->add_user >>
method will be added to the end of the sequence for all-user method calls
(even if the user already existed, they will be moved to the end).

B<Keep in mind> that the mech object given to this user is brand new.
So you need to use absolute URLs when making the next call to,
say C<< ->get_ok >>, methods on this user (or with the next
all-users method).

=head2 C<remove_user>

    my $user_args = $mech->remove_user('guest');

B<Takes> a valid user alias.
Removes user with that alias from the MultiMech mech object bundle. If
removing an existing user, that user's user args hashref will be returned,
otherwise the return value is an empty list or C<undef>, depending on the
context. The C<mech> key in the returned hashref will contain the mech
object that was being used for that user.

Note that you can't delete all the users you have. If attempting to
delete the last remaining user, the module will
L<croak()|https://metacpan.org/pod/Carp>.

=head2 C<all_users>

    for ( $mech->all_users ) {
        print "I'm testing user $_\n";
    }

Takes no arguments. Returns a list of user aliases currently used by
MultiMech, in the same order in which they are called in
all-object method calls.

=head1 AUTHOR

Zoffix Znet, C<< <zoffix at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-test-www-mechanize-multimech at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-WWW-Mechanize-MultiMech>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::WWW::Mechanize::MultiMech

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-WWW-Mechanize-MultiMech>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-WWW-Mechanize-MultiMech>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-WWW-Mechanize-MultiMech>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-WWW-Mechanize-MultiMech/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Zoffix Znet.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut
