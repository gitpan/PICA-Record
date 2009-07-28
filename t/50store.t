#!perl -Tw

use strict;

use Test::More qw(no_plan);

use PICA::Record qw(getrecord);
use PICA::Store;
use IO::File;
use File::Temp qw(tempdir);
use Data::Dumper;

require "./t/teststore.pl";

if ( $ENV{PICASTORE_TEST} ) {
    my $webcat = PICA::Store->new( config => $ENV{PICASTORE_TEST} );
    teststore( $webcat );
} else {
    diag("Set PICASTORE_TEST to enable additional tests of PICA::Store!");
    ok(1);
}

# create a configuration file and a SQLiteStore
my $dir = tempdir( UNLINK => 1 );
chdir $dir;

my $fh;
open $fh, ">picastore.conf";
print $fh "SQLite=tmp.db\n";
close $fh;

my $store = PICA::Store->new( conf => undef );
isa_ok( $store, 'PICA::Store', 'created a new store via config file' );
my %result = $store->create( PICA::Record->new('021A $aShort Title') );
ok ( $result{id}, 'created a record' );


