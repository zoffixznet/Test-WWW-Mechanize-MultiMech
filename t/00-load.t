#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Test::WWW::Mechanize::MultiMech' ) || print "Bail out!\n";
}

diag( "Testing Test::WWW::Mechanize::MultiMech $Test::WWW::Mechanize::MultiMech::VERSION, Perl $], $^X" );
