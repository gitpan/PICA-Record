#!perl -Tw

use strict;

use Test::More tests => 26;

use PICA::Parser qw(parsefile parsedata);
use PICA::PlainParser;
use PICA::XMLParser;
use PICA::Record;
use PICA::Writer;

my $record;
my $plainpicafile = "t/kochbuch.pica";
sub handle_record { $record = shift; }

# parse from a file
PICA::Parser->parsefile( $plainpicafile, Record => \&handle_record );
isa_ok( $record, 'PICA::Record' );
undef $record;

# parse from a file handle
open PICA, $plainpicafile;
PICA::Parser->parsefile( \*PICA, Record => \&handle_record );
close PICA;
isa_ok( $record, 'PICA::Record' );
undef $record;

# parse from a file with default parameters
my $parser = PICA::Parser->new( Record => \&handle_record );
$parser->parsefile( $plainpicafile );
isa_ok( $record, 'PICA::Record' );
undef $record;

# parse from a file handle with default parameters
open PICA, $plainpicafile;
$parser->parsefile( \*PICA, Record => \&handle_record );
close PICA;
isa_ok( $record, 'PICA::Record' );
undef $record;

# parse from a string
open PICA, $plainpicafile;
my $picadata = join( "", <PICA> );
close PICA;
PICA::Parser->parsedata( $picadata, Record => \&handle_record );
isa_ok( $record, 'PICA::Record' );
undef $record;

# parse from an array
open PICA, $plainpicafile;
my @picadata = <PICA>;
close PICA;
PICA::Parser->parsedata( \@picadata, Record => \&handle_record );
isa_ok( $record, 'PICA::Record' );
undef $record;

# parse from a function
open PICA, $plainpicafile;
PICA::Parser->parsedata( sub {return readline PICA;}, Record => \&handle_record );
isa_ok( $record, 'PICA::Record' );

# parse dump format
my $writer = PICA::Writer->new();
$parser = PICA::Parser->new( Dumpformat => 1, Record => sub { $writer->write( shift ); } );
$parser->parsefile("t/dumpformat");
ok( $writer->counter() == 3, 'parse dumpformat (records)' );
ok( $writer->fields() == 92, 'parse dumpformat (fields)' );

# check proceed mode and non-proceed mode
$parser = PICA::Parser->new( Proceed => 0 );
$parser->parsedata($picadata);
$parser->parsedata($picadata);
ok( $parser->counter == 1, "reset counter" );

$parser = PICA::Parser->new( Proceed => 1 );
$parser->parsedata($picadata);
$parser->parsedata($picadata);
ok( $parser->counter == 2, "proceed" );

# run parsefile in many ways
test_parsefile("t/kochbuch.pica");
test_parsefile("t/record.xml");

sub test_parsefile {
    my $file = shift;
    my ($parser, $visited);
    open FILE, $file;

    $visited = 0;
    parsefile($file, Record => sub { $visited++; } );
    ok( $visited == 1, "call parsefile as exported function with file name");

    if (!($file =~ /.xml$/)) {
        $visited = 0;
        parsefile( \*FILE, Record => sub { $visited++; } );
        ok( $visited == 1, "call parsefile as exported function with file handle");
    }

    $visited = 0;
    PICA::Parser->parsefile($file, Record => sub { $visited++; });
    ok( $visited == 1, "call parsefile as function with file name");

    $parser = PICA::Parser->new();
    $visited = 0;
    $parser->parsefile($file, Proceed => 1);
    $parser->parsefile($file, Record => sub { $visited++; } );
    $parser->parsefile($file);
    ok( $visited == 2, "changed handler at call of parsefile");
    ok( $parser->counter() == 1 , "ignore Proceed when calling parsefile");
}

# run parsedata in many ways
test_parsedata("t/kochbuch.pica");
test_parsedata("t/record.xml");

sub test_parsedata {
    my $file = shift;
    open FILE, $file;
    my $data = join( "", <FILE> );
    close FILE;

    my ($parser, $visited);
    my %options = ($file =~ /.xml$/) ? (Format => "xml") : ();

    $visited = 0;
    PICA::Parser->parsedata($data, Record => sub { $visited++; }, %options);
    ok( $visited == 1, "call parsedata as function with data");

    $parser = PICA::Parser->new();
    $visited = 0;
    $parser->parsedata($data, Proceed => 1, %options);
    $parser->parsedata($data, Record => sub { $visited++; }, %options);
    $parser->parsedata($data, %options);
    ok( $visited == 2, "changed handler at call of parsefile");
    ok( $parser->counter() == 1 , "ignore Proceed when calling parsedata");
}

