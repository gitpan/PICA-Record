#!perl -Tw

use strict;

use Test::More tests => 6;
use Encode;
use File::Temp qw(tempfile);

use_ok("PICA::XMLWriter");
use_ok("PICA::XMLParser");
use_ok("PICA::Parser");

my ($record) = PICA::Parser->parsefile("t/minimal.xml")->records();
isa_ok($record, "PICA::Record");

open XML, "t/minimal.xml";
my $xmldata = join("",grep { !($_ =~ /^<\?/); } <XML>);
close XML;

my $str = "<collection xmlns='info:srw/schema/5/picaXML-v1.0'>\n"
        . $record->to_xml() . "</collection>\n";
$str = decode_utf8($str);
$xmldata = decode_utf8($xmldata);
is( $str, $xmldata, "to_xml" );

my ($fh, $filename) = tempfile(UNLINK => 1);
binmode $fh, ":utf8"; # avoid "Wide character in print" warning

my $writer = PICA::XMLWriter->new( $fh );
$writer->write( $record )->end_document();
close $fh;

open XML, $filename || print "FAILED\n";
my $xmlout = join("",<XML>);
close XML;

$xmlout = "<collection xmlns='info:srw/schema/5/picaXML-v1.0'>\n"
           . $xmlout . "</collection>\n";
$xmlout = decode_utf8($xmlout);

#is( $xmlout, $xmldata, "XMLWriter");


# add <collection> and <?xsl-stylesheet

open XML, "t/minimal.xml";
$xmldata = join("",<XML>);
close XML;

$str = $record->to_xml( header=>1, xslt=>'../script/pica2html.xsl' );
$xmldata = decode_utf8($xmldata);
$str = decode_utf8($str);
is($str, $xmldata, "to_xml with header and xslt");

#print STDERR "$xmldata\n";
#print STDERR  . "\n";
# TODO
# $writer = PICA::XMLWriter->new( $fh );
# $writer->start_document()->write( $record )->end_document();

