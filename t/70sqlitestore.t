#!perl -Tw

use strict;

use Test::More qw(no_plan);

use PICA::Record;
use PICA::SQLiteStore;
use IO::File;
use File::Temp qw(tempfile);
use Data::Dumper;

# record to insert
my $record = PICA::Record->new( IO::File->new("t/minimal.pica") );

# create new store
my ($dbfile, $dbfilename) = tempfile();
my $store = PICA::SQLiteStore->new( $dbfilename, rebuild => 1);
isa_ok( $store, "PICA::SQLiteStore", "new PICA::SQLiteStore $dbfilename" );

# run general store tests
require "./t/teststore.pl";
teststore( $store );

# TODO: Should the history really be empty because of deletions ?
my $history = $store->history();
ok( ref($history) eq "ARRAY", "history" );

# reconnect via config file
$store->{dbh}->disconnect;

my ($configfile, $configfilename) = tempfile();
print $configfile "SQLite=$dbfilename\n";
close $configfile;

$store = PICA::SQLiteStore->new( config => $configfilename, rebuild => 0 );
isa_ok( $store, "PICA::SQLiteStore", "reconnect via config file" );

my $h2 = $store->history();
is( scalar @$h2, scalar @$history, "still same history: " . @$history );

# additional SQLiteStore tests

my %h = $store->create( $record );
my $id = $h{id};

%h = $store->get($id);
is( $h{record}->to_string, $record->to_string, "reuse database file" );

# recreate the database file
$store->{dbh}->disconnect;
$store = PICA::SQLiteStore->new( $dbfilename, rebuild => 1 );
isa_ok( $store, "PICA::SQLiteStore", "rebuild database" );

my $rc = $store->recentchanges();
is_deeply( $rc, [], "empty database" );

%h = $store->create($record);
$rc = $store->recentchanges();
is( scalar @$rc, 1, "recent changes (1)" );

$id = $rc->[0]->{ppn};
my $version = $rc->[0]->{version};

is_deeply( $store->history($id), $rc, "history==recent changes (1)" );

my $pn = $store->prevnext($id, $version);
is_deeply ( $pn, {}, "prevnext (0)" );

$record = PICA::Record->new('028A $0Hello');
$store->update( $id, $record, $version );
$history = $store->history($id);
$rc = $store->recentchanges();
is_deeply( $history, $rc, "history==recent changes (2)" );

#print Dumper($store->history($id));
#print Dumper($rc);

$store->{dbh}->disconnect;

# TODO: contributions
# TODO: deletions (check that a version is inserted)

__END__

# TODO: require SQLite 3.3 (?)

# TODO: prevnext (for 1,2,3)

# TODO: run additional sqlitestore-only tests

# print Dumper($rc) . "\n";
# print Dumper($rc) . "\n";
