#!perl -Tw

use strict;

use Test::More tests => 49;

use PICA::Field;
use XML::Writer;

my $normalized = "\x1E028A \x1F9117060275\x1F8Martin Schrettinger\x1FdMartin\x1FaSchrettinger\x0A";
my $plain = "028A \$9117060275\$8Martin Schrettinger\$dMartin\$aSchrettinger";
my $winibw = "028A \x839117060275\x838Martin Schrettinger\x83dMartin\x83aSchrettinger";
my $packed = "028A\$9117060275\$8Martin Schrettinger\$dMartin\$aSchrettinger";
my $picamarc = "028A \x9f9117060275\x9f8Martin Schrettinger\x9fdMartin\x9faSchrettinger";

my ($field, $value, $writer, $string, $prefixmap);

$field = PICA::Field->new("028A","9" => "117060275", "8" => "Martin Schrettinger", "d" => "Martin", "a" => "Schrettinger");
isa_ok( $field, 'PICA::Field');
is( $field->normalized(), $normalized, 'new with tag and list of subfields');

$field = PICA::Field->new( $plain );
is( $field->normalized(), $normalized, 'new with plain PICA+');

$field = PICA::Field->new( $normalized );
is( $field->normalized(), $normalized, 'new with normalized PICA+');

$field = PICA::Field->new( $winibw );
is( $field->normalized(), $normalized, 'new with WinIBW PICA+');

$field = PICA::Field->new( $packed );
is( $field->normalized(), $normalized, 'new with packed');

$field = PICA::Field->new( $picamarc );
is( $field->normalized(), $normalized, 'new with picamarc');

my $xml = join('',<DATA>);
is( $field->to_xml(), $xml, 'to_xml()');

$xml =~ s/pica:/foo:/g;
$xml =~ s/xmlns:pica/xmlns:foo/;
$prefixmap = {'info:srw/schema/5/picaXML-v1.0'=>'foo'};
is( $field->to_xml( PREFIX_MAP => $prefixmap ), $xml, 'to_xml(PREFIX_MAP)' );

$string = "";
$writer = XML::Writer->new( OUTPUT => \$string, NAMESPACES => 1, PREFIX_MAP => $prefixmap );
$field->to_xml( $writer );
is( $string, $xml, 'to_xml(PREFIX_MAP) with XML::Writer to string' );

$xml =~ s/foo://g;
$xml =~ s/xmlns:foo/xmlns/g;
$prefixmap = {'info:srw/schema/5/picaXML-v1.0'=>''};
is( $field->to_xml( PREFIX_MAP => $prefixmap ), $xml, 'to_xml(PREFIX_MAP:"")' );

$string = "";
$writer = XML::Writer->new( OUTPUT => \$string, NAMESPACES => 1, PREFIX_MAP => $prefixmap );
$field->to_xml( $writer );
is( $string, $xml, 'to_xml(PREFIX_MAP:"") with XML::Writer' );

$xml =~ s/ xmlns="[^"]+"//;
$string = "";
$writer = XML::Writer->new( OUTPUT => \$string, NAMESPACES => 0 );
$field->to_xml( $writer );
is( $string, $xml, 'to_xml( no namspaces ) with XML::Writer' );

$xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n$xml";
is ( $field->to_xml( header => 1, NAMESPACES => 0 ), $xml, 'to_xml with xmlDecl' );

$field = PICA::Field->new("028A","9" => "117060275");
$field->add( "8" => "Martin Schrettinger", "d" => "Martin", "a" => "Schrettinger" );
ok( $field->normalized() eq $normalized, 'add method');

is( $field->subfield('1tix'), undef, 'subfield() non existing subfield' );
is( $field->sf('1tix'), undef, 'sf() non existing subfield' );

my @all = $field->sf();
is ( @all, 4, 'get all subfields (sf)');

@all = $field->subfield();
is ( @all, 4, 'get all subfields (subfield)');

$value = $field->sf('8');
is( $value, "Martin Schrettinger", "sf() to get one subfield value" );

$value = $field->subfield('8');
is( $value, "Martin Schrettinger", "subfield() to get one subfield value" );

@all = $field->sf('8');
is_deeply( \@all, ["Martin Schrettinger"], "sf() to one subfield as value" );

@all = $field->subfield('8');
is_deeply( \@all, ["Martin Schrettinger"], "subfield() to one subfield as value" );

@all = $field->content();
is ( @all, 4, 'get all subfields (content)');

my @c = $field->content();

#use Data::Dumper;
#print STDERR Dumper(@c) . "\n";
ok ( $c[1][0] eq '8' && $c[1][1] eq "Martin Schrettinger", 'get all subfields as array');

my $fcopy = $field->copy(); #PICA::Field->new( $field );
isa_ok( $fcopy, 'PICA::Field');
ok( $fcopy->normalized() eq $normalized, 'copy' );
$field->tag('012A');
$field->update('9'=>'123456789');
is( $fcopy->normalized(), $normalized, 'copy' );

$field = PICA::Field->new("028A","d" => "Karl", "a" => "Marx");
isa_ok( $field, 'PICA::Field');
ok( !$field->is_empty(), '!is_empty()' );

$field = PICA::Field->new("028A","d" => "", "a" => "Marx");
ok( !$field->is_empty(), '!is_empty()' );
is( $field->purged->to_string, "028A \$aMarx\n", "purged empty field");

$field = PICA::Field->new("028A", "d"=>"", "a"=>"" );
ok( $field->is_empty(), 'is_empty()' );
is( join('', $field->empty_subfields() ), "da", 'empty_subfields' );
is( $field->purged, undef, "purged empty field");

# normally fields without subfields should not occur, but if...
is( $field->to_string(subfields=>'x'), "", "empty field");
$field->{_subfields} = [];
ok( $field->is_empty(), 'empty field');
is( $field->to_string, "", "empty field (to_string)");
my $emptyxml = '<pica:datafield tag="028A" xmlns:pica="info:srw/schema/5/picaXML-v1.0"></pica:datafield>';
is( $field->to_xml, $emptyxml, "empty field (to_xml)");
is( $field->purged, undef, "purged empty field");

$field->tag("028C/01");
ok( $field->tag eq "028C/01", 'set tag' );

$field = PICA::Field->new( '021A', 'a' => 'Get a $, loose a $!', 'b' => 'test' );
my $enc = '021A $aGet a $$, loose a $$!$btest';
is( $field->to_string(), "$enc\n", 'dollar signs in field values (1)' );

$field = PICA::Field->parse($enc);
is( $field->to_string(endfield=>''), $enc, 'dollar signs in field values (2)' );

$enc = '021A $aGet a $$, loose a $$';
$field = PICA::Field->parse($enc);
is( $field->to_string(endfield=>''), $enc, 'dollar signs in field values (3)' );

ok( $field->sf('a') eq 'Get a $, loose a $', 'Field->sf (scalar)' );
$field = PICA::Field->parse('123A $axx$ayy');
my @sf = $field->subfield('a');
ok ($sf[0] eq 'xx' && $sf[1] eq 'yy', 'Field->sf (array)');

$field = PICA::Field->parse('123A $axx$byy$czz');
@sf = $field->sf('a','c');
ok ($sf[0] eq 'xx' && $sf[1] eq 'zz', 'Field->sf (multiple)');

# newlines in field values
$field = PICA::Field->new( '021A', 'a' => "This\nare\n\t\nlines" );
is( $field->sf('a'), "This are lines", "newline in value (1)");
is( $field->to_string(), "021A \$aThis are lines\n", "newline in value (2)");


__DATA__
<pica:datafield tag="028A" xmlns:pica="info:srw/schema/5/picaXML-v1.0"><pica:subfield code="9">117060275</pica:subfield><pica:subfield code="8">Martin Schrettinger</pica:subfield><pica:subfield code="d">Martin</pica:subfield><pica:subfield code="a">Schrettinger</pica:subfield></pica:datafield>