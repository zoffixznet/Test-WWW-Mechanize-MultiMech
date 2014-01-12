use 5.006;
use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Test::WWW::Mechanize::MultiMech',
    license             => 'Artistic_2_0',
    dist_author         => q{Zoffix Znet <zoffix@cpan.org>},
    dist_version_from   => 'lib/Test/WWW/Mechanize/MultiMech.pm',
    release_status      => 'stable',
    configure_requires => {
        'Module::Build' => 0,
    },
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'Carp'                 => 1.26,
        'Test::WWW::Mechanize' => 1.44,
        'Test::Builder'        => 0.99,
        'perl' => '5.006',
    },
    add_to_cleanup     => [ 'Test-WWW-Mechanize-MultiMech-*' ],
    create_makefile_pl => 'traditional',
);
if ( $ENV{RELEASE_TESTING} ) {
    system('pod2text lib/Test/WWW/Mechanize/MultiMech.pm > README');
}
$builder->create_build_script();
