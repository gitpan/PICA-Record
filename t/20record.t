#!perl -Tw

use strict;

use Test::More tests => 35;

use PICA::Field;
use PICA::Record;

# PICA::Record constructor
my $testrecord = PICA::Record->new(
    '009P/03', '0' => 'http',
    '010@', 'a' => 'eng',
    '037A', 'a' => '1st note',
    '037A', 'a' => '2nd note',
    '111@', 'x' => 'foo'
);
isa_ok( $testrecord, 'PICA::Record');

# create a field for appending
my $field = PICA::Field->new("028A","9" => "117060275", "d" => "Martin", "a" => "Schrettinger");
isa_ok( $field, 'PICA::Field');

# this is how the record with the field should look like
my $normalized = "\x1D\x0A\x1E028A \x1F9117060275\x1FdMartin\x1FaSchrettinger\x0A";

# create a new record (empty)
my $record = new PICA::Record();
isa_ok( $record, 'PICA::Record');

# append a field
$record->append($field);
is( $record->normalized(), $normalized, 'Record->normalized()');

# directly pass a field to new()
$record = PICA::Record->new($field);
is( $record->normalized(), $normalized, 'Record->normalized()');

# directly pass data to new() for parsing
$record = PICA::Record->new( $normalized );
is( $record->normalized(), $normalized, 'Record->normalized()');

# directly pass data to new()
$record = PICA::Record->new("028A","9" => "117060275", "d" => "Martin", "a" => "Schrettinger");
is( $record->normalized(), $normalized, 'Record->normalized()');

# use append to add fields
$record = PICA::Record->new();
$record->append("028A","9" => "117060275", "d" => "Martin", "a" => "Schrettinger");
is( $record->normalized(), $normalized, 'Record->normalized()');

$record = PICA::Record->new();
$record->append($field, '037A','a' => 'First note');
is( scalar $record->all_fields(), 2 , "Record->append()" );

$record = PICA::Record->new();
$record->append(
        $field,
        '037A','a' => 'First note',
        PICA::Field->new('037A','a' => 'Second note'),
        '037A','a' => 'Third note',
);
is( scalar $record->all_fields(), 4 , "Record->append()" );

# use the same object of provided
is( $record->subfield('028A','9'), '117060275', "Field value" );
$field->update('9'=>'12345');
is( $record->subfield('028A','9'), '12345', "Field value modified" );

$record = PICA::Record->new();
$record->append(
    '037A', 'a' => '1st note',
    '037A', 'a' => '2nd note',
);
is( scalar $record->all_fields(), 2 , "Record->append()" );

# clone constructor
my $recordclone = PICA::Record->new($record);
is( scalar $recordclone->all_fields(), 2 , "PICA::Record clone constructor" );
$record->delete_fields('037A');
is( scalar $recordclone->all_fields(), 2 , "PICA::Record clone a new object" );


### field()
$record = $testrecord;
my @fields = $record->field("009P/03");
is( scalar @fields, 1 , "Record->field()" );
@fields = $record->f("037A");
is( scalar @fields, 2 , "Record->field()" );
@fields = $record->field("009P/03");
is( scalar @fields, 1 , "Record->field()" );
@fields = $record->field("0...(/..)?");
is( scalar @fields, 4 , "Record->field()" );
@fields = $record->all_fields();
is( scalar @fields, 5 , "Record->field()" );
@fields = $record->field(2, "0...(/..)?");
is( scalar @fields, 2, "Record->field() with limit" );
@fields = $record->field(0, "0...(/..)?");
is( scalar @fields, 4 , "Record->field() with limit zero" );
@fields = $record->f(1, "037A");
is( scalar @fields, 1 , "Record->field() with limit one" );
@fields = $record->f(99, "037A");
is( scalar @fields, 2 , "Record->field() with limit high" );

### subfield()
is( $record->subfield('009P/03$0'), "http", "subfield()");
my @s = $record->subfield(0,'....$a');
is( scalar @s, 3, "subfield() with limit zero");
@s = $record->subfield(2,'....$a');
is( scalar @s, 2, "subfield() with limit");


### delete_fields
my $r = PICA::Record->new($record);
$r->delete_fields("037A");
is( scalar $r->all_fields(), 3 , "delete()" );

$r = PICA::Record->new($record);
$r->delete_fields("0...");
is( scalar $r->all_fields(), 2 , "delete()" );

$r = PICA::Record->new($record);
$r->delete_fields("0..@","111@");
is( scalar $r->all_fields(), 3 , "delete()" );

### replace fields
$record = $testrecord;
$record->replace('010@', PICA::Field->new('010@', 'a' => 'ger'));
is( $record->subfield('010@$a'), 'ger', "replace field");

$record->replace('010@', 'a' => 'fra');
is( $record->subfield('010@$a'), 'fra', "replace field");

### parse WinIBW output
use PICA::Parser;

PICA::Parser->parsefile( "t/winibwsave.example", Record => sub { $record = shift; } );
isa_ok( $record, 'PICA::Record' );

# test bibliographic()
my $main = $record->main_record();
isa_ok( $main, 'PICA::Record' );

### parse normalized by autodetection
open PICA, "t/bib.pica"; # TODO: bib.pica is bytestream, not character-stream!
$normalized = join( "", <PICA> );
close PICA;

$r = PICA::Record->new( $normalized );
is( $r->all_fields(), 24, "detect and read normalized pica" );
