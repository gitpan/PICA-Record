#!perl -Tw

use strict;

use Test::More qw(no_plan);

use PICA::Record;
use PICA::Store;

if (!$ENV{WEBCAT_TEST_CONFIG}) {
    diag("Skipping tests of PICA::Store, set WEBCAT_TEST_CONFIG to point to config file");
    ok(1);
    exit;
}

my %config;
if ( open F, ("<".$ENV{WEBCAT_TEST_CONFIG}) ) {
    while(<F>) {
        chomp;
        next if /^\s*#/;
        if ( /^\s*([a-z_]+)\s*=\s*([^ ]+)/ ) {
            $config{$1} = $2;
        }
    }
}
close F;

ok ( %config, "read webcat config file");
exit unless %config;

my $webcat = PICA::Store->new(
    SOAP => $config{soap},
    userkey => $config{userkey},
    password => $config{password},
    dbsid => $config{dbsid}
);

my $record = PICA::Record->new("002@ \$0Aau\n021A \$aDas Kapital\n028A \$dKarl\$aMarx");


my %result = $webcat->create($record);
ok ($result{record} && $result{id}, "createRecord");

%result = $webcat->get( $result{id} );
ok ($result{record} && $result{id}, "getRecord");

$record = PICA::Record->new("002@ \$0Aau\n021A \$aDas zweite Kapital\n028A \$dKarl\$aMarx");
%result = $webcat->update($result{id}, $record, $result{version});
ok ($result{record} && $result{id}, "updateRecord");

#%result = $webcat->update($result{id}, $testrecord);
#ok ($result{record} && $result{id}, "updateRecord without version");

%result = $webcat->delete($result{id});
ok ($result{id}, "deleteRecord");

%result = $webcat->get($result{id});
ok ($result{errorcode}, "getRecord of non-existing id");

# TODO: check unicode safety

ok(1);