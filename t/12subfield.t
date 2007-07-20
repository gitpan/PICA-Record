#!perl -Tw

use strict;

use Test::More tests => 8;

use PICA::Record;
use PICA::Field;

my $field = PICA::Field->new("028A","d" => "Given1", "d" => "Given2", "a" => "Surname", "x" => "Stuff");
isa_ok( $field, 'PICA::Field');

my $s = $field->subfield("d");
ok( $s , 'scalar context' );

my @s = $field->subfield("d");
ok( @s == 2 , 'array context' );

my $record = PICA::Record->new();
$record->append($field);

$s = $record->subfield("028A", "d");
ok( $s , 'scalar context' );

@s = $record->subfield("028A", "d");
ok( @s == 2 , 'array context' );

$s = $record->subfield('028A$d');
ok( $s , 'field$subfield' );

@s = $record->subfield("028A", "da");
ok( @s == 3 , 'multiple subfields' );

@s = $record->values('028A$a', '028A$z', '028A$d' );
ok( @s == 3 , 'multiple subfields with values()' );
