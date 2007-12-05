#!perl -Tw

use strict;

use Test::More tests => 29;

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
ok( $record->normalized() eq $normalized, 'Record->normalized()');

# directly pass a field to new()
$record = PICA::Record->new($field);
ok( $record->normalized() eq $normalized, 'Record->normalized()');

# directly pass data to new() for parsing
$record = PICA::Record->new( $normalized );
ok( $record->normalized() eq $normalized, 'Record->normalized()');

# directly pass data to new()
$record = PICA::Record->new("028A","9" => "117060275", "d" => "Martin", "a" => "Schrettinger");
ok( $record->normalized() eq $normalized, 'Record->normalized()');

# use append to add fields
$record = PICA::Record->new();
$record->append("028A","9" => "117060275", "d" => "Martin", "a" => "Schrettinger");
ok( $record->normalized() eq $normalized, 'Record->normalized()');

$record = PICA::Record->new();
$record->append($field, '037A','a' => 'First note');
ok( scalar $record->all_fields() == 2 , "Record->append()" );

$record = PICA::Record->new();
$record->append(
        $field,
        '037A','a' => 'First note',
        PICA::Field->new('037A','a' => 'Second note'),
        '037A','a' => 'Third note',
);
ok( scalar $record->all_fields() == 4 , "Record->append()" );

# use the same object of provided
ok ( $record->subfield('028A','9') eq '117060275', "Field value" );
$field->update('9'=>'12345');
ok ( $record->subfield('028A','9') eq '12345', "Field value modified" );

$record = PICA::Record->new();
$record->append(
    '037A', 'a' => '1st note',
    '037A', 'a' => '2nd note',
);
ok( scalar $record->all_fields() == 2 , "Record->append()" );

# clone constructor
my $recordclone = PICA::Record->new($record);
ok( scalar $recordclone->all_fields() == 2 , "PICA::Record clone constructor" );
$record->delete_fields('037A');
ok( scalar $recordclone->all_fields() == 2 , "PICA::Record clone a new object" );


### field()
$record = $testrecord;
my @fields = $record->field("009P/03");
ok( scalar @fields == 1 , "Record->field()" );
@fields = $record->field("037A");
ok( scalar @fields == 2 , "Record->field()" );
@fields = $record->field("009P/03");
ok( scalar @fields == 1 , "Record->field()" );
@fields = $record->field("0...(/..)?");
ok( scalar @fields == 4 , "Record->field()" );
@fields = $record->all_fields();
ok( scalar @fields == 5 , "Record->field()" );

### delete_fields
my $r = PICA::Record->new($record);
$r->delete_fields("037A");
ok( scalar $r->all_fields() == 3 , "delete()" );

$r = PICA::Record->new($record);
$r->delete_fields("0...");
ok( scalar $r->all_fields() == 2 , "delete()" );

$r = PICA::Record->new($record);
$r->delete_fields("0..@","111@");
ok( scalar $r->all_fields() == 3 , "delete()" );

### replace fields
$record = $testrecord;
$record->replace('010@', PICA::Field->new('010@', 'a' => 'ger'));
ok( $record->subfield('010@$a') eq 'ger', "replace field");

$record->replace('010@', 'a' => 'fra');
ok( $record->subfield('010@$a') eq 'fra', "replace field");

### parse WinIBW output
use PICA::Parser;

PICA::Parser->parsefile( "t/winibwsave.example", Record => sub { $record = shift; } );
isa_ok( $record, 'PICA::Record' );

# test main_record() and local_record()
my $main = $record->main_record();
isa_ok( $main, 'PICA::Record' );

my $local = $record->local_record();
isa_ok( $local, 'PICA::Record' );

ok ( scalar ($local->all_fields) == 4, 'PICA::Record->all_fields' );
