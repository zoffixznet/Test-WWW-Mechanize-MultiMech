package Test::WWW::Mechanize::MultiMech;

use 5.006;
use strict;
use warnings FATAL => 'all';
our $VERSION = '1.001';
use Test::WWW::Mechanize;
use Test::Builder qw//;
use Carp qw/croak/;

use Data::Dumper;

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
    for my $login ( @{$self->{USERS_ORDER}} ) {
        my $mech = $users->{ $login }{mech};

        $mech->get_ok(
            $page,
            "[$login] get_ok($page)",
        );

        my $user_args = { %args };
        if ( $user_args->{fields} ) {
            $user_args->{fields} = {%{ $user_args->{fields} }};
        }

        for ( values %{ $user_args->{fields} || {} } ) {
            next unless ref eq 'SCALAR';
            if ( $$_ eq 'LOGIN'   ) { $_ = $login;                   }
            elsif ( $$_ eq 'PASS' ) { $_ = $users->{ $login }{pass}; }
        }

        $mech->submit_form_ok(
            $user_args,
            "[$login] Submitting login form",
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

    croak qq|Can't locate object method "$method" via package |
        . __PACKAGE__;
}

sub _call_mech_method_on_each_user {
    my ( $self, $method, $args ) = @_;

    my %returns;
    for my $login ( @{$self->{USERS_ORDER}} ) {
        _diag("\n[$login] Calling ->$method()\n");
        $returns{ $login }
        = $self->{USERS}{ $login }{mech}->$method( @$args );
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
        %$args,
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


=head1 DESCRIPTION

Ofttimes I had to test a web app where I had several user permission
categories and I needed to ensure that, for example, only admins get
the admin panel,

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
