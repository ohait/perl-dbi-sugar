#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'DBI::Sugar' ) || print "Bail out!\n";
}

#diag( "Testing DBI::Sugar $DBI::Sugar::VERSION, Perl $], $^X" );
