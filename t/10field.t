#!perl -Tw

use strict;

use Test::More tests => 26;

use PICA::Field;

my $normalized = "\x1E028A \x1F9117060275\x1F8Martin Schrettinger\x1FdMartin\x1FaSchrettinger\x0A";
my $plain = "028A \$9117060275\$8Martin Schrettinger\$dMartin\$aSchrettinger";
my $winibw = "028A \x839117060275\x838Martin Schrettinger\x83dMartin\x83aSchrettinger";
my $packed = "028A\$9117060275\$8Martin Schrettinger\$dMartin\$aSchrettinger";
my $picamarc = "028A \x9f9117060275\x9f8Martin Schrettinger\x9fdMartin\x9faSchrettinger";

my $field;

$field = PICA::Field->new("028A","9" => "117060275", "8" => "Martin Schrettinger", "d" => "Martin", "a" => "Schrettinger");
isa_ok( $field, 'PICA::Field');
ok( $field->normalized() eq $normalized, 'new with tag and list of subfields');

$field = PICA::Field->new( $plain );
ok( $field->normalized() eq $normalized, 'new with plain PICA+');

$field = PICA::Field->new( $normalized );
ok( $field->normalized() eq $normalized, 'new with normalized PICA+');

$field = PICA::Field->new( $winibw );
ok( $field->normalized() eq $normalized, 'new with WinIBW PICA+');

$field = PICA::Field->new( $packed );
ok( $field->normalized() eq $normalized, 'new with packed');

$field = PICA::Field->new( $picamarc );
ok( $field->normalized() eq $normalized, 'new with picamarc');

$field = PICA::Field->new("028A","9" => "117060275");
$field->add( "8" => "Martin Schrettinger", "d" => "Martin", "a" => "Schrettinger" );
ok( $field->normalized() eq $normalized, 'add method');

ok ( ! $field->sf('1tix') , 'non existing subfield');

my @all = $field->sf();
ok ( @all == 4, 'get all subfields (sf)');

@all = $field->content();
ok ( @all == 4, 'get all subfields (content)');

my @c = $field->content();
#use Data::Dumper;
#print STDERR Dumper(@c) . "\n";
ok ( $c[1][0] eq '8' && $c[1][1] eq "Martin Schrettinger", 'get all subfields as array');


my $fcopy = $field->copy(); #PICA::Field->new( $field );
isa_ok( $fcopy, 'PICA::Field');
ok( $fcopy->normalized() eq $normalized, 'copy' );
$field->tag('012A');
$field->update('9'=>'123456789');
ok( $fcopy->normalized() eq $normalized, 'copy' );

$field = PICA::Field->new("028A","d" => "Karl", "a" => "Marx");
isa_ok( $field, 'PICA::Field');

ok( !$field->is_empty(), '!is_empty()' );

$field = PICA::Field->new("028A", "d"=>"", "a"=>"" );
ok( $field->is_empty(), 'is_empty()' );

ok( join('', $field->empty_subfields() ) eq "da", 'empty_subfields' );

$field->tag("028C/01");
ok( $field->tag eq "028C/01", 'set tag' );

$field = PICA::Field->new( '021A', 'a' => 'Get a $, loose a $!', 'b' => 'test' );
my $enc = '021A $aGet a $$, loose a $$!$btest';
ok( $field->to_string() eq $enc, 'dollar signs in field values (1)' );

$field = PICA::Field->parse($enc);
ok( $field->to_string() eq $enc, 'dollar signs in field values (2)' );

$enc = '021A $aGet a $$, loose a $$';
$field = PICA::Field->parse($enc);
ok( $field->to_string() eq $enc, 'dollar signs in field values (3)' );

ok( $field->sf('a') eq 'Get a $, loose a $', 'Field->sf (scalar)' );
$field = PICA::Field->parse('123A $axx$ayy');
my @sf = $field->subfield('a');
ok ($sf[0] eq 'xx' && $sf[1] eq 'yy', 'Field->sf (array)');

$field = PICA::Field->parse('123A $axx$byy$czz');
@sf = $field->sf('a','c');
ok ($sf[0] eq 'xx' && $sf[1] eq 'zz', 'Field->sf (multiple)');
