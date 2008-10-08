#!/usr/bin/perl

use lib "../lib/";
use PICA::Webcat;
use PICA::Record;

if (@ARGV != 4) {
    print "Usage: $0 baseurl dbsid userkey password\n";
    print "  Test script to demonstrate PICA::Webcat\n";
    exit 0;
}

my ($baseurl, $dbsid, $userkey, $password) = @ARGV;

my $server = PICA::Webcat->new($baseurl, $userkey, $password, $dbsid);

my $record = PICA::Record->new(
    '002@','0'=>'Aau',
    '011@','a'=>'2008',
    '021A','a'=>'the @book of test',
    '028A','d'=>'Tom','a'=>'Testboy'
);

print "insert record\n";
%result = $server->insert( $record );
check(%result);

my $ppn = $result{ppn};

print "retrieve record $ppn\n";
%result = $server->retrieve( $ppn );
check(%result);

my $ppn = $result{ppn};
my $version = $result{version};

print $result{record}->to_string();

$record->replace( '028A','d'=>'Tina','a'=>'Testgirl' );
print "update record $ppn\n";
%result = $server->update( $ppn, $record, $version );
check(%result);
print $result{record}->to_string();

print "delete record $ppn\n";
%result = $server->delete( $ppn );
check(%result);


sub check {
    my %result = @_;
    return unless $result{errorcode};
    print STDERR $result{errorcode} . ": "
               . $result{errormessage} . "\n";
    exit 0;
}
