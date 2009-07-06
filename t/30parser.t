#!perl -Tw

use strict;

use Test::More tests => 46;

use PICA::Parser qw(parsefile parsedata);
use PICA::PlainParser;
use PICA::XMLParser;
use PICA::Record;
use PICA::Writer;
use IO::File;
use Encode;

my $record;
my $plainpicafile = "t/kochbuch.pica";
sub handle_record { $record = shift; }

# parse from a file
PICA::Parser->parsefile( $plainpicafile, Record => \&handle_record );
isa_ok( $record, 'PICA::Record' );
undef $record;

# parse via PICA::Record->new
$record = PICA::Record->new( new IO::File("< $plainpicafile") );
isa_ok( $record, 'PICA::Record' );
is( scalar $record->all_fields(), 26, "read via IO::File" );
undef $record;

open (F, "<", $plainpicafile);
$record = PICA::Record->new( \*F );
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
open PICA2, "<", $plainpicafile;
PICA::Parser->parsedata( sub {return readline PICA2;}, Record => \&handle_record );
close PICA2;
isa_ok( $record, 'PICA::Record' );
is( scalar $record->all_fields(), 26, 'parse from function' );

# parse a PICA::Record (by clone constructor)
my $recordclone = $record;
undef $record;
PICA::Parser->parsedata( $recordclone, Record => \&handle_record );
$recordclone->delete_fields('....');
is( scalar $record->all_fields(), 26 , "parse another PICA::Record" );

# parse dump format
my $writer = PICA::Writer->new();
$parser = PICA::Parser->new( Record => sub { 
    my $record = shift;
    $writer->write( $record ); 
    return $record;
} );
$parser->parsefile("t/dumpformat");
is( $writer->counter(), 3, 'parse dumpformat (records) - writer' );
is( $parser->counter(), 3, 'parse dumpformat (records) - parser' );
is( $writer->fields(), 92, 'parse dumpformat (fields)' );
$writer->reset();

# parse dumpformat (from file)
$parser->parsefile("t/bib.pica");
is ($writer->fields(), 24, 'parse dumpformat (from file)' );

# parse from IO::Handle
use IO::File;
my $fh = new IO::File("< t/dumpformat");
$parser = PICA::Parser->new();
$parser->parsefile( $fh );
is( $parser->counter, 3, 'parse dumpformat (records)' );

# check proceed mode and non-proceed mode
$parser = PICA::Parser->new( Proceed => 0 );
$parser->parsedata($picadata);
$parser->parsedata($picadata);
is( $parser->counter, 1, "reset counter" );

$parser = PICA::Parser->new( Proceed => 1 );
$parser->parsedata($picadata);
$parser->parsedata($picadata);
is( $parser->counter, 2, "proceed" );

# one call
$parser = PICA::Parser->parsedata($picadata);
is( $parser->counter, 1, "one call" );

# stored records
my @r = PICA::Parser->parsedata($picadata)->records();
is( scalar @r, 1, "one call (->records)" );

# run parsefile in many ways
test_parsefile("t/kochbuch.pica");
test_parsefile("t/record.xml");

sub test_parsefile {
    my $file = shift;
    my ($parser, $visited);
    open FILE, $file;

    $visited = 0;
    parsefile($file, Record => sub { $visited++; } );
    is( $visited, 1, "call parsefile as exported function with file name");

    if (!($file =~ /.xml$/)) {
        $visited = 0;
        parsefile( \*FILE, Record => sub { $visited++; } );
        is( $visited, 1, "call parsefile as exported function with file handle");
    }

    $visited = 0;
    PICA::Parser->parsefile($file, Record => sub { $visited++; });
    is( $visited, 1, "call parsefile as function with file name");

    $parser = PICA::Parser->new();
    $visited = 0;
    $parser->parsefile($file, Proceed => 1);
    $parser->parsefile($file, Record => sub { $visited++; } );
    $parser->parsefile($file);
    is( $visited, 2, "changed handler at call of parsefile");
    is( $parser->counter(), 1 , "ignore Proceed when calling parsefile");
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
    is( $visited, 1, "call parsedata as function with data");

    $parser = PICA::Parser->new();
    $visited = 0;
    $parser->parsedata($data, Proceed => 1, %options);
    $parser->parsedata($data, Record => sub { $visited++; }, %options);
    $parser->parsedata($data, %options);
    is( $visited, 2, "changed handler at call of parsefile");
    is( $parser->counter(), 1 , "ignore Proceed when calling parsedata");
}

# use PICA::Writer as record handler
my $file = "t/cjk.pica";
open FILE, $file;
my $data = join( "", <FILE> );
close FILE;
my $s;
$writer = PICA::Writer->new( \$s );
$parser = PICA::Parser->new( Record => $writer )->parsefile($file);
is ( encode_utf8($s), "$data\n", 'PICA::Writer as record handler');


my @records;

if ( 0 ) { # TODO
    @records = PICA::Parser->parsefile( "t/winibwsave.example", Limit => 2 )->records();
    is( scalar @records, 2, "limit" );

    @records = PICA::Parser->parsefile( "t/winibwsave.example", Offset => 3 )->records();
    is( scalar @records, 3, "offset" );
}

# test error handlers

my ($msg, $badfield);
my $badrecord = "foo\n021@ \$ahi\nbar";
@records = PICA::Parser->parsedata( $badrecord,
    , FieldError => sub { $badfield .= $_[1]; return; } 
)->records();
is( scalar @records, 1, "field error (ignore)" );
is( $badfield, "foobar", "field error (handle)" );

@records = PICA::Parser->parsedata(
    "foo", FieldError => sub { return PICA::Field->new('028A $9117060275'); } 
)->records();
ok( @records && $records[0]->field("028A"), "field error (fix)" );


$msg = undef;
$parser = PICA::Parser->new(
    FieldError => sub { return shift; },
    RecordError => sub { $msg = shift; } 
);

$msg = undef;
@records = $parser->parsedata( $picadata . "\n" . $badrecord );
ok( $msg, "ignore bad records (1)" );
is( $parser->counter, 2, "count bad records but ignore them" );
is( scalar @records, 1,  "ignore bad records but read good records" );

$msg = undef;
$parser->parsedata( $badrecord );
ok( $msg, "field error triggers record error" );

# empty record
$msg = undef;
$parser = PICA::Parser->new( RecordError => sub { $msg = shift; } );
$parser->parsedata("\n");
is( $msg, "empty record", "empty record" );

$msg = undef;
PICA::Parser->new( 
    Record => sub { return "bad"; },
    RecordError => sub { $msg = shift; }
)->parsedata( "\n" );
is( $msg, "bad", "record handler produces error" );

