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

my $webcat = PICA::Store->new( config => $ENV{WEBCAT_CONF_TEST} );
my (@records, %result, $record);

# use a simple record
$record = PICA::Record->new("002@ \$0Aau\n021A \$aDas zweite Kapital\n028A \$dKarl\$aMarx");
push @records, $record;

# use a record with Unicode
$record = PICA::Record->new( IO::File->new("t/minimal.pica") );
$record->delete_fields('003@'); # remove PPN
push @records, $record;

while( @records ) {
    $record = shift @records;
    #print $record->to_string() . "\n";

    my %result = $webcat->create($record);
    ok ($result{record} && $result{id}, "createRecord") 
        or print "#" . $result{errormessage} . "\n";
    my $id = $result{id};

    %result = $webcat->get( $id );
    ok ($result{record} && $result{id}, "getRecord");
    my $version = $result{version};

    if (@records) {
        $record = $records[0];
        %result = $webcat->update( $id, $record, $version );
        ok ($result{record} && $result{id}, "updateRecord") 
            or print "#" . $result{errormessage} . "\n";
        #%result = $webcat->update( $id, $testrecord);
        #ok ($result{record} && $result{id}, "updateRecord without version");
    }

    %result = $webcat->delete( $id );
    is ( $result{id}, $id, "deleteRecord");
}

%result = $webcat->get( 123 );
ok ($result{errorcode}, "getRecord of non-existing id");
