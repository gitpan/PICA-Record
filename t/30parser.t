#!perl -Tw

use strict;

use Test::More tests => 9;

BEGIN {
    use_ok( 'PICA::Parser' );
    use_ok( 'PICA::Record' );
}

use PICA::Parser;
use PICA::PlainParser;
use PICA::XMLParser;
use PICA::Record;

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
