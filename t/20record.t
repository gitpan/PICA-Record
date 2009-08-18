#!perl -Tw

use strict;
use utf8;

use Test::More qw(no_plan);

use PICA::Field;
use PICA::Record qw(getrecord);
use IO::File;

my $files = "t/files";

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
ok( $record->empty, 'empty record' );
ok( !$record, 'empty record (overload)' );

# append a field
$record->append($field);
is( $record->normalized(), $normalized, 'Record->normalized()');
ok( !$record->empty, 'not empty record' );
ok( $record, 'not empty record (overload)' );

# directly pass a field to new()
$record = PICA::Record->new($field);
is( $record->normalized(), $normalized, 'Record->normalized()');

# directly pass data to new() for parsing
print "N:$normalized\n";
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

is( $record->ppn(), undef, "ppn() not existing" );
is( $record->epn(), undef, "epn() not existing" );

my @missing = $record->epn();
is_deeply( \@missing, [], "epn() not existing" );

# use the same object of provided
is( $record->subfield('028A','9'), '117060275', "Field value" );
$field->update('9'=>'12345');
is( $record->subfield('028A','9'), '12345', "Field value modified" );

# appendif
$record = PICA::Record->new();
$record->appendif('037A','a' => undef);
is( scalar $record->all_fields(), 0 , "Record->appendif()" );
$record->appendif('037A','a' => 123);
is( scalar $record->all_fields(), 1 , "Record->appendif()" );
$record->appendif('028A','9' => undef, 'd'=>'Max');
is( scalar $record->all_fields(), 2 , "Record->appendif()" );
is( $record->to_string(), "037A \$a123\n028A \$dMax\n" , "Record->appendif()" );

$record = PICA::Record->new();
$record->append(
    '037A', 'a' => '1st note',
    '037A', 'a' => '2nd note',
);
is( scalar $record->all_fields(), 2 , "Record->append()" );

# values
is_deeply( [ $record->values('037A$a') ], [ '1st note', '2nd note' ], 'values' );
is_deeply( [ $record->values('037A_a') ], [ '1st note', '2nd note' ], 'values' );

# clone constructor
my $recordclone = PICA::Record->new($record);
is( scalar $recordclone->all_fields(), 2 , "PICA::Record clone constructor" );
$record->delete_fields('037A');
is( scalar $recordclone->all_fields(), 2 , "PICA::Record cloned a new object" );

# occurrence
$record = PICA::Record->new( '233A/03', 'x' => 'foo' );
is( $record->occ, '03', 'occurrence' );

### field()
$record = $testrecord;
my @fields = $record->field("009P/03","a"=>"http://example.com");
is( scalar @fields, 1 , "Record->field()" );
@fields = $record->f("037A");
is( scalar @fields, 2 , "Record->field()" );
@fields = $record->field("009P/03");
is( scalar @fields, 1 , "Record->field()" );
@fields = $record->field("0...(/..)?");
is( scalar @fields, 4 , "Record->field()" );
@fields = $record->field( qr/^0...(\/..)?$/ );
is( scalar @fields, 4 , "Record->field(qr)" );
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

@fields = $record->f( "037A", sub { return $_[0] if $_[0]->sf('a'); } );
is( scalar @fields, 2 , "Record->field() with filter" );

@fields = $record->f( ".*", sub { return unless $_[0]->sf('a'); $_[0]; } );
is( scalar @fields, 3 , "Record->field() with filter" );

my $r2 = PICA::Record->new($record);
@fields = $r2->f( "0.*", sub { return unless $_[0]->sf('a'); $_[0]->update('a'=>'xx'); $_[0]; } );
is_deeply( [ map { $_->sf('a'); } @fields ], ['xx','xx','xx'], "Record->field() with filter" );

@fields = $r2->f( sub { return unless $_[0]->sf('a'); $_[0]->update('a'=>'xx'); $_[0]; } );
is_deeply( [ map { $_->sf('a'); } @fields ], ['xx','xx','xx'], "Record->field() with filter" );

### subfield()
is( $record->subfield('009P/03$0'), "http", "subfield() \$");
is( $record->subfield('009P/03_0'), "http", "subfield() _");
my @s = $record->subfield(0,'....$a');
is( scalar @s, 3, "subfield() with limit zero");
@s = $record->subfield(2,'...._a');
is( scalar @s, 2, "subfield() with limit");
is( $record->subfield('123$x'), undef, "subfield() not exist" );

### values
# my @titles = $pica->values( '021A$a', '025@$a', '026C$a');
my @v = $record->values( '0[01]..(/..)?', '0a' );
is_deeply( \@v, [ 'http', 'eng' ], 'values (1)' );
@v = $record->values( 2, '010@_a', '111@', 'x', '037A_a' );
is_deeply( \@v, [ 'eng', 'foo' ], 'values (2)' );
@v = $record->values( 3, '010@_a', '111@', 'x', '037A_a' );
is_deeply( \@v, [ 'eng', 'foo', '1st note' ], 'values (3)' );
@v = $record->values( '010@', 'a', '111@', 'x' );
is_deeply( \@v, [ 'eng', 'foo' ], 'values (4)' );
@v = $record->values( '010@', 'a', '111@$x' );
is_deeply( \@v, [ 'eng', 'foo' ], 'values (5)' );

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

### parse normalized by autodetection
open PICA, "$files/bib.pica"; # TODO: bib.pica is bytestream, not character-stream!
$normalized = join( "", <PICA> );
close PICA;

$r = PICA::Record->new( $normalized );
is( $r->all_fields(), 24, "detect and read normalized pica" );

my $file = IO::File->new("$files/minimal.pica");
$record = PICA::Record->new( $file );
$file->seek(0,0);
my $minimal = join('',$file->getlines());
is( $record->to_string(), $minimal, "to_string()" );
is( $record->as_string(), $minimal, "as_string()" );
is( $record, $minimal, "stringify" );

# parse non-existing file
$record = eval { PICA::Record->new( IO::File->new('xxx') ); };
ok( $@ && !$record, 'failed to read from not-existing file' );

# newlines in field values
$record = PICA::Record->new( '021A', 'a' => "This\nare\n\t\nlines" );
is( $record->sf('021A$a'), "This are lines", "newline in value (1, \$)" );
is( $record->sf('021A_a'), "This are lines", "newline in value (1, _)" );
is( $record->to_string(), "021A \$aThis are lines\n", "newline in value (2)" );

# also test getrecord
$record = getrecord("$files/graveyard.pica");
is( scalar $record->all_fields(), 62, "parsed graveyard.pica" );

### PPN

my $ppn = $record->ppn();
is( $ppn, '588923168', "ppn (plain)" );

$ppn = $record->subfield('003@_0');
is( $ppn, '588923168', "ppn as subfield" );

$ppn = '123456789';
is( $record->ppn($ppn), $ppn, 'set ppn' );

$record->append('003@','0'=>'588923168');
my @ppn = $record->subfield('003@_0');
is_deeply( \@ppn, [ '588923168' ], 'only one PPN' );

$record->replace('003@','0'=>'123456789');
is( $record->ppn, '123456789', 'replace PPN' );


my $epn = $record->epn();
my @epns = $record->epn();

is( $epn, 917400194, "epn() as scalar" );
is_deeply( \@epns, [917400194,923091475,923091483,923091491], "epn() as array" );

### holdings

$record = PICA::Record->new( IO::File->new("$files/bgb.example") );

my @holdings = $record->holdings();
is( scalar @holdings, 56, 'holdings' );
my @a = $record->local_records;
is( scalar @a, scalar @holdings, 'local_records' );

my @copies = $record->items();
ok( scalar @copies == 336, 'items' );
@a = $record->copy_records;
is( scalar @a, scalar @copies, 'copy_records' );

ok( scalar $holdings[0]->items() == 1, "items (1)");
ok( scalar $holdings[4]->items() == 2, "items (2)");
ok( scalar $holdings[5]->items() == 26, "items (26)");

### UTF8 and encodings
my $cjk = "我国民事立法的回顾与展望";
$record = new PICA::Record( new IO::File("$files/cjk.pica") );
is( $record->sf('021A_a'), $cjk, 'CJK record' );


__END__

### TODO: parse WinIBW output : this is possible via winibw2pica (test needed)
if (1) {
  use PICA::Parser;

  PICA::Parser->parsefile( "$files/winibwsave.example", Record => sub { $record = shift; } );
  isa_ok( $record, 'PICA::Record' );

  # test bibliographic()
  my $main = $record->main_record();
  isa_ok( $main, 'PICA::Record' );
}

__END__
# TODO: test to_xml

