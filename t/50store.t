#!perl -Tw

use strict;

use Test::More qw(no_plan);

use PICA::Record;
use PICA::Store;
use IO::File;
use Data::Dumper;

if (!$ENV{WEBCAT_CONF_TEST}) {
    diag("Skipping tests of PICA::Store, set WEBCAT_CONF_TEST to point to config file");
    ok(1);
    exit;
}

require "./t/teststore.pl";

my $webcat = PICA::Store->new( config => $ENV{WEBCAT_CONF_TEST} );

teststore( $webcat );
