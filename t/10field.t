#!perl -Tw

use strict;

use Test::More qw(no_plan);

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
$xml =~ s/\n$//m;
is( $field->xml, $xml, 'xml()');

$xml =~ s/pica:/foo:/g;
$xml =~ s/xmlns:pica/xmlns:foo/;
$prefixmap = {'info:srw/schema/5/picaXML-v1.0'=>'foo'};
is( $field->xml( PREFIX_MAP => $prefixmap ), $xml, 'xml(PREFIX_MAP)' );

$string = "";
$writer = XML::Writer->new( OUTPUT => \$string, NAMESPACES => 1, PREFIX_MAP => $prefixmap );
my $w = $field->xml( $writer );
is( $string, $xml, 'xml(PREFIX_MAP) with XML::Writer' );
isa_ok( $w, 'XML::Writer' );

$xml =~ s/foo://g;
$xml =~ s/xmlns:foo/xmlns/g;
$prefixmap = {'info:srw/schema/5/picaXML-v1.0'=>''};
is( $field->xml( PREFIX_MAP => $prefixmap ), $xml, 'xml(PREFIX_MAP:"")' );

$string = "";
$writer = XML::Writer->new( OUTPUT => \$string, NAMESPACES => 1, PREFIX_MAP => $prefixmap );
$field->xml( $writer );
is( $string, $xml, 'xml(PREFIX_MAP:"") with XML::Writer' );

$xml =~ s/ xmlns="[^"]+"//;
$string = "";
$writer = XML::Writer->new( OUTPUT => \$string, NAMESPACES => 0 );
$field->xml( $writer );
is( $string, $xml, 'xml( no namspaces ) with XML::Writer' );

$string = "!";
$field->xml( \$string, NAMESPACES => 0 );
is( $string, "!$xml", 'xml( no namspaces ) to string' );

$xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n$xml";
is ( $field->xml( header => 1, NAMESPACES => 0 ), $xml, 'xml with xmlDecl' );

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

ok ( $c[1][0] eq '8' && $c[1][1] eq "Martin Schrettinger", 'get all subfields as array');

my $fcopy = $field->copy(); #PICA::Field->new( $field );
isa_ok( $fcopy, 'PICA::Field');
ok( $fcopy->normalized() eq $normalized, 'copy' );
$field->tag('012A');
$field->update('9'=>'123456789');
is( $fcopy->normalized(), $normalized, 'copy' );

$field = PICA::Field->new("028A","d" => "Karl", "a" => "Marx");
isa_ok( $field, 'PICA::Field');
ok( ! $field->empty, '!empty' );
ok( $field, 'overloaded bool' );

$field = PICA::Field->new("\x1E028A \x1F9117060275\x1FdMartin\x1FaSchrettinger");
ok( $field, 'overloaded bool' );

$field = PICA::Field->new("028A","d" => "", "a" => "Marx");
ok( !$field->empty, '!empty()' );
is( $field->purged->to_string, "028A \$aMarx\n", "purged empty field");

$field = PICA::Field->new("028A", "d"=>"", "a"=>"" );
ok( $field->empty, 'empty()' );
is( join('', $field->empty_subfields() ), "da", 'empty_subfields' );
is( $field->purged, undef, "purged empty field");

# normally fields without subfields should not occur, but if...
is( $field->as_string(subfields=>'x'), "", "empty field");
$field->{_subfields} = [];
ok( $field->empty, 'empty field');
is( $field->as_string, "", "empty field (as_string)");
is( $field, "", "empty field (as_string, overload)");
my $emptyxml = '<pica:datafield tag="028A" xmlns:pica="info:srw/schema/5/picaXML-v1.0"></pica:datafield>';
is( $field->xml, $emptyxml, "empty field (xml)");
is( $field->purged, undef, "purged empty field");

$field->tag("028C/01");
ok( $field->tag eq "028C/01", 'set tag' );
is( $field->occurrence, '01', 'get occurrence' );

$field->occurrence(2);
is( $field->occ, '02', 'set occurrence' );

$field = PICA::Field->new( '021A', 'a' => 'Get a $, loose a $!', 'b' => 'test' );
my $enc = '021A $aGet a $$, loose a $$!$btest';
is( "$field", "$enc\n", 'dollar signs in field values (1)' );

$field = PICA::Field->parse($enc);
is( $field->as_string(endfield=>''), $enc, 'dollar signs in field values (2)' );

$enc = '021A $aGet a $$, loose a $$';
$field = PICA::Field->parse($enc);
is( $field->as_string(endfield=>''), $enc, 'dollar signs in field values (3)' );

ok( $field->sf('a') eq 'Get a $, loose a $', 'Field->sf (scalar)' );
$field = PICA::Field->parse('123A $axx$ayy');
my @sf = $field->subfield('a');
ok ($sf[0] eq 'xx' && $sf[1] eq 'yy', 'Field->sf (array)');

$field = PICA::Field->parse('123A $axx$byy$czz');
@sf = $field->sf('a','c');
is_deeply ( \@sf, ['xx','zz'], 'Field->sf (multiple) - 1');
@sf = $field->sf( qr/[ac]/ );
is_deeply ( \@sf, ['xx','zz'], 'Field->sf (multiple) - 2');
@sf = $field->sf( qr/[a-c]/ );
is_deeply ( \@sf, ['xx','yy','zz'], 'Field->sf (multiple) - 3');
@sf = $field->sf( 'a-b' );
is_deeply ( \@sf, ['xx','yy'], 'Field->sf (multiple) - 4');

# newlines in field values
$field = PICA::Field->new( '021A', 'a' => "This\nare\n\t\nlines" );
is( $field->sf('a'), "This are lines", "newline in value (1)");
is( $field, "021A \$aThis are lines\n", "newline in value (2)");


__DATA__
<pica:datafield tag="028A" xmlns:pica="info:srw/schema/5/picaXML-v1.0"><pica:subfield code="9">117060275</pica:subfield><pica:subfield code="8">Martin Schrettinger</pica:subfield><pica:subfield code="d">Martin</pica:subfield><pica:subfield code="a">Schrettinger</pica:subfield></pica:datafield>
