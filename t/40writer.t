#!perl -Tw

use strict;
use utf8;

use Test::More tests => 13;
use Encode;
use File::Temp qw(tempfile);
use XML::Writer;

my $files = "t/files";

use_ok("PICA::Writer");
use_ok("PICA::XMLParser");
use_ok("PICA::Parser");
use_ok("PICA::Field");
use_ok("PICA::Record");

# simple writing
my $w = PICA::Writer->new();
$w->write( PICA::Record->new('123@','0'=>'foo') );
is( $w->counter, 1, "simple writing (record)" );
is( $w->fields, 1, "simple writing (field)" );

my $s="";
PICA::Writer->new( \$s )->write( 
   PICA::Record->new('042A', '1' => 'bar' ),
   PICA::Record->new('045B', 'X' => 'doz' ) 
)->end();
is ( $s, "042A \$1bar\n\n045B \$Xdoz\n", "multiple records" );

# prepare
my ($record, $xmldata, $str);

($record) = PICA::Parser->parsefile("$files/minimal.xml")->records();
isa_ok($record, "PICA::Record");

# open XML file
my $fxml;
open $fxml, "$files/minimal.xml";
binmode $fxml, ":utf8";
$xmldata = join("",grep { !($_ =~ /^<\?|^$/); } <$fxml>);
close $fxml;

# write manually with xml
my $writer = XML::Writer->new( 
  DATA_MODE => 1, DATA_INDENT => 2, 
  NAMESPACES => 1, PREFIX_MAP => {$PICA::Record::XMLNAMESPACE=>''},
  OUTPUT => \$str
);
$writer->startTag([$PICA::Record::XMLNAMESPACE,'collection']);
$record->xml( $writer );
$writer->endTag();
is( "$str\n", $xmldata, "xml" );

# open XML file
open $fxml, "$files/minimal.xml";
binmode $fxml, ":utf8";
$xmldata = join("", <$fxml>);
close $fxml;


# write to file

my ($fh, $filename) = tempfile(UNLINK => 1);
binmode $fh, ":utf8";

my $prefixmap = {'info:srw/schema/5/picaXML-v1.0'=>''};
$w = PICA::Writer->new( $fh, format => 'xml', 
  DATA_MODE => 1, DATA_INDENT => 2, 
  NAMESPACES => 1, PREFIX_MAP => $prefixmap, 
  xslt => '../script/pica2html.xsl'
);
$w->write( $record )->end();
close $fh;

is( file2string($filename), $xmldata, "format => 'xml'" );

sub file2string {
    my $fname = shift;
    my $fh;
    open( $fh, "<:utf8", $fname ) or return "failed to open $fname";
    my $string = join('',<$fh>);
    close $fh;
    return $string;
}

# write to XML with pretty print
($fh, $filename) = tempfile( SUFFIX => '.xml', UNLINK => 1 );
close $fh;
$w = PICA::Writer->new( $filename, pretty => 1, xslt => '../script/pica2html.xsl' );
$w->write( $record )->end();

is( file2string($filename), $xmldata, "format => 'xml' (implicit, pretty)" );

$s = "";
$w = PICA::Writer->new( \$s, format => 'xml' );
PICA::Parser->parsefile( "$files/graveyard.pica", Record => $w );
$w->end();
is ("$s", file2string("$files/graveyard.xml"), "default XML conversion");


__END__

TODO: write to a stream in another encoding

if(0) {
$str = "";
$w = PICA::Writer->new( \$str, format => 'xml',
  DATA_MODE => 1, DATA_INDENT => 2, 
  NAMESPACES => 1, PREFIX_MAP => {$PICA::Record::XMLNAMESPACE=>''},
);
$w->start()->write( $record )->end();
$w->start(); #->write($record);
# TODO: write fields
is( $str, $xmldata, "write via PICA::Writer" );
}

# add <collection> and <?xsl-stylesheet
