#!perl -Tw

use strict;

use Test::More tests => 13;

BEGIN {
    use_ok( 'PICA::XMLParser' );
    use_ok( 'PICA::Parser' );
    use_ok( 'PICA::Record' );
    use_ok( 'IO::File' );
}

use PICA::XMLParser;
use PICA::Parser;

my @xmldata = <DATA>;              # array
my $xmldata = join("", @xmldata);  # string
my $record;
sub handle_record { $record = shift; }

# Create a parser and parse string
my $parser = PICA::XMLParser->new( Record => \&handle_record );
$parser->parsedata($xmldata);
isa_ok( $record, 'PICA::Record' );
undef $record;

# Use PICA::Parser and parse string
PICA::Parser->parsedata( $xmldata, Record => \&handle_record, Format=>"xml" );
isa_ok( $record, 'PICA::Record');
undef $record;
 
# Use PICA::Parser and parse array
PICA::Parser->parsedata( \@xmldata, Record => \&handle_record, Format=>"xml" );
isa_ok( $record, 'PICA::Record');
undef $record;

my $xmlfile = "t/record.xml";

# Use PICA::Parser and parse from xml file
PICA::Parser->parsefile( $xmlfile, Record => \&handle_record );
isa_ok( $record, 'PICA::Record');
undef $record;

# parse from IO::Handle
use IO::File;
my $fh = new IO::File("< $xmlfile");
PICA::Parser->parsefile( $fh, Record => \&handle_record, Format => "xml" );
isa_ok( $record, 'PICA::Record');

# Use PICA::Parser and parse from file handle with XML data
open XML, $xmlfile;
PICA::Parser->parsefile( \*XML, Record => \&handle_record, Format => "xml" );
isa_ok( $record, 'PICA::Record');
undef $record;
close XML;

# parse from a function
open XML, $xmlfile;
PICA::Parser->parsedata( sub {return readline XML;}, 
    Record => \&handle_record,
    Format => "xml"
);
isa_ok( $record, 'PICA::Record' );
undef $record;

# check proceed mode and non-proceed mode
$parser = PICA::XMLParser->new( Proceed => 0 );
$parser->parsedata($xmldata);
$parser->parsedata($xmldata);
ok( $parser->counter == 1, "reset counter" );

$parser = PICA::XMLParser->new( Proceed => 1 );
$parser->parsedata($xmldata);
$parser->parsedata($xmldata);
ok( $parser->counter == 2, "proceed" );

__END__
<?xml version="1.0"?>
<record>
  <field tag="021A">
    <subfield code="0">Test</subfield>
  </field>
</record>