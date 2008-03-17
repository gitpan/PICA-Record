package PICA::Record;

=head1 NAME

PICA::Record - Perl extension for handling PICA+ records

=cut

use strict;
use integer;

use Exporter;

use vars qw($VERSION @ISA @EXPORT);
require Exporter;
@ISA = qw(Exporter);

$VERSION = "0.35";

use POSIX qw(strftime);
use PICA::Field;
use Carp qw(croak);

=head1 DESCRIPTION

Module for handling PICA records as objects.
See L<PICA::Tutorial> for an introduction.

=head1 METHODS

=head2 new ( [ ...data... ] )

Base constructor for the class. A single string will be parsed line by 
line into L<PICA::Field> objects, empty lines and start record markers will 
be skipped. More then one or non scalar parameters will be passed to 
C<append> so you can use the constructor in the same way:

  my $record = PICA::Record->new('037A','a' => 'My note');

If no data is given then it just returns a completely empty record.

=cut

sub new() {
    my $class = shift;
    my $first = $_[0];

    $class = ref($class) || $class; # Handle cloning
    my $self = bless {
        _fields => []
    }, $class;

    # pass croak without including Record.pm at the stack trace
    local $Carp::CarpLevel = 1;

    if ($first) {
        if ($#_ == 0 and ref(\$first) eq 'SCALAR') {
            my @lines = split("\n", $first);

            foreach my $line (@lines) {
                $line =~ s/^\x1D//; # start of record
                next if !$line;     # skip empty lines

                my $field = PICA::Field->parse($line);
                push (@{$self->{_fields}}, $field) if $field;
            }
        } else {
            $self->append(@_);
        }
    }

    return $self;
} # new()

=head2 copy

Creates a clone of this record by copying all fields.

=cut

sub copy {
    my $self = shift;
    return PICA::Record->new( $self );
} # copy()

=head2 all_fields()

Returns an array of all the fields in the record. The array contains 
a C<PICA::Field> object for each field in the record. An empty array 
is returns if the record is empty.

=cut

sub all_fields() {
    my $self = shift;
    croak("You called all_fields() but you probably want field()") if @_;
    return @{$self->{_fields}};
}

=head2 field( $tagspec(s) )

Returns a list of C<PICA::Field> objects with tags that
match the field specifier, or in scalar context, just
the first matching Field.

You may specify multiple tags and use regular expressions.

  my $field  = $record->field("021A","021C");
  my $field  = $record->field("009P/03");
  my @fields = $record->field("02..");
  my @fields = $record->field("039[B-E]");

=cut

my %field_regex;

sub field {
    my $self = shift;
    my @specs = @_;

    my @list = ();
    return @list if !@specs;

    for my $tag ( @specs ) {
        my $regex = _get_regex($tag);

        for my $maybe ( $self->all_fields ) {
            if ( $maybe->tag() =~ $regex ) {
                return $maybe unless wantarray;

                push( @list, $maybe );
            }
        }
    }

    return @list;
} # field()

=head2 subfield

Shortcut method for getting just the subfield's value of a tag (see L<PICA::Field>). 
Returns a list of subfield values that match or in scalar context, just the 
first matching subfield.

These are equivalent (in scalar context):

  my $title = $pica->field('021A')->subfield('a');
  my $title = $pica->subfield('021A','a');

You may also specify both field and subfield seperated by '$'.
Don't forget to quote the dollar sign!

  my $title = $pica->subfield('021A$a');
  my $title = $pica->subfield("021A\$a");
  my $title = $pica->subfield("021A$a"); # this won't work!

If either the field or subfield can't be found, C<undef> is returned.

You may also use wildcards like in C<field()> and the C<subfield()> method of L<PICA::Field>:

  my @values = $pica->subfield('005A', '0a');    # 005A$0 and 005A$a
  my @values = $pica->subfield('005[AIJ]', '0'); # 005A$0, 005I$0, and 005J$0

=cut

sub subfield {
    my ($self, $tag, $subfield) = @_;
    return unless defined $tag;

    ($tag, $subfield) = split(/\$/,$tag) if (!defined $subfield and index($tag, '$') > 3);
    croak("No subfields specified in '$tag'") if !defined $subfield;

    my @fields = $self->field($tag) or return;

    my @list = ();

    foreach my $f (@fields) {
        my @s = $f->subfield($subfield);
        if (@s) {
            return shift @s unless wantarray;
            push( @list, @s );
        }
    }

    return @list;
} # subfield()

=head2 values

Shortcut method to get subfield values of multiple fields and subfields. The fields and subfields 
are specified in a list of strings, for instance:

  my @titles = $pica->values( '021A$a', '025@$a', '026C$a');

This method always returns an array.

You may also use wildcards in the field specifications, see C<subfield()> and C<field()>.

=cut

sub values {
    my $self = shift;

    my @list = ();

    foreach my $spec (@_) {
        croak("Not a field/tag-specification: $spec") if (!(index($spec, '$') > 3));
        my @results = $self->subfield($spec);
        push (@list, @results);
    }

    return @list;
} # values()

=head2 main_record  

Get the main record (all tags starting with '0').

=cut

sub main_record {
  my ($self) = @_;
  my @fields = $self->field("0...(/..)?");

  my $record = PICA::Record->new(@fields);
}

=head2 local_record

Get the local record (all tags starting with '1').

=cut

sub local_record {
  my ($self) = @_;
  my @fields = $self->field("1...(/..)?");

  my $record = PICA::Record->new(@fields);
}

=head2 copy_record

Get the copy record (all tags starting with '2').

=cut

sub copy_record {
  my ($self) = @_;
  my @fields = $self->field("2...(/..)?");

  my $record = PICA::Record->new(@fields);
}

=head2 is_empty

Return true if the record is empty (no fields or all fields empty)

=cut

sub is_empty() {
    my $self = shift;
    foreach my $field (@{$self->{_fields}}) {
        return 0 if !$field->is_empty();
    }
    return 1;
}

=head2 delete_fields ( <tagspec(s)> )

Delete fields specified by tags. You can also use wildcards, 
see C<field()> for examples Returns the number of deleted fields.

=cut

sub delete_fields {
    my $self = shift;
    my @specs = @_;

    return 0 if !@specs;
    my $c = 0;

    for my $tag ( @specs ) {
        my $regex = _get_regex($tag);

        my $i=0;
        for my $maybe ( $self->all_fields ) {
            if ( $maybe->tag() =~ $regex ) {
                splice( @{$self->{_fields}}, $i, 1);
                $c++;
            } else {
                $i++;
            }
        }
    } # for $tag

    return $c;
}

=head2 append ( ...fields or records... )

Appends one or more fields to the end of the record. Parameters can be
L<PICA::Field> objects or parameters that are passed to C<PICA::Field->new>.

    my $field = PICA::Field->new('037A','a' => 'My note');
    $record->append($field);

is equivalent to

    $record->append('037A','a' => 'My note');

You can also append multiple fields with one call:

    my $field = PICA::Field->new('037A','a' => 'First note');
    $record->append($field, '037A','a' => 'Second note');

    $record->append(
        '037A', 'a' => '1st note',
        '037A', 'a' => '2nd note',
    );

Please not that passed L<PICA::Field> objects are not be copied but directly
used:

    my $field = PICA::Field->new('037A','a' => 'My note');
    $record->append($field);
    $field->replace('a' => 'Your note'); # Also changes $record's field!

You can avoid this by cloning fields:

    $record->append($field->copy());

You can also append copies of all fields of another record:

    $record->append( $record2 );

The append method returns the number of fields appended.

=cut

sub append {
    my $self = shift;

    my $c = 0;

    while (@_) {
        # Append a field (whithout creating a copy)
        while (@_ and ref($_[0]) eq 'PICA::Field') {
            push(@{ $self->{_fields} }, shift);
            $c++;
        }
        # Append a whole record (copy all its fields)
        while (@_ and ref($_[0]) eq 'PICA::Record') {
            my $record = shift;
            for my $field ( $record->all_fields ) {
                push(@{ $self->{_fields} }, $field->copy );
                $c++;
            }
        }
        if (@_) {
            my @params = (shift);
            while (@_ and ref($_[0]) ne 'PICA::Field') {
                push @params, shift;
                push @params, shift;
                last if (@_ and ref($_[0]) ne 'PICA::Field' and length($_[0]) > 1);
            }
            if (@params) {

                # pass croak without including Record.pm at the stack trace
                local $Carp::CarpLevel = 1;

                my $field = PICA::Field->new( @params );
                push(@{ $self->{_fields} }, $field);

                $c++;
            }
        }
    }

    return $c;
}

=head2 replace( $tag, $field or @fieldspec )

Replace a field. You must pass a tag and a field. 
Attention: Only the first occurence will be replaced
so better not use this method for repeatable fields.

=cut

sub replace {
    my $self = shift;
    my $tag = shift;

    croak("Not a valid tag: $tag") unless parse_pp_tag($tag);

    my $replace;

    if (@_ and ref($_[0]) eq 'PICA::Field') {
        $replace = shift;
    } else {
        $replace = PICA::Field->new($tag, @_);
    } 

    my $regex = _get_regex($tag);

    for my $field ( $self->all_fields ) {
        if ( $field->tag() =~ $regex ) {
            $field->replace($replace);
            return;
        }
    }
}

=head2 sort() 

Sort all fields. Most times the order of fields is not changed 
and not relevant but sorted fields are helpful for viewing records.

=cut

sub sort() {
    my $self = shift;

    @{$self->{_fields}} = sort {$a->tag() cmp $b->tag()} @{$self->{_fields}};
}


=head2 add_headers

Add header fields to a L<PICA::Record>. You must specify two named parameters
(eln and satus). This method is experimental. There is no test whether the 
header fields already exist.

=cut

sub add_headers {
    my ($self, %params) = @_;

    my $eln = $params{eln};
    croak("add_headers needs an ELN") unless defined $eln;

    my $status = $params{status};
    croak("add_headers needs status") unless defined $status;

    my @timestamp = defined $params{timestamp} ? @{$params{timestamp}} : localtime;
    # TODO: Test timestamp

    my $hdate = strftime ("$eln:%d-%m-%g", @timestamp);
    my $htime = strftime ("%H:%M:%S", @timestamp);

    # Pica3: 000K - Unicode-Kennzeichen
    $self->append( "001U", '0' => 'utf8' );

    # PICA3: 0200 - Kennung und Datum der Ersterfassung
    # http://www.gbv.de/vgm/info/mitglieder/02Verbund/01Erschliessung/02Richtlinien/01KatRicht/0200.pdf
    $self->append( "001A", '0' => $hdate );

    # PICA3: 0200 - Kennung und Datum der letzten Aenderung
    # http://www.gbv.de/vgm/info/mitglieder/02Verbund/01Erschliessung/02Richtlinien/01KatRicht/0210.pdf
    $self->append( "001B", '0' => $hdate, 't' => $htime );

    # PICA3: 0230 - Kennung und Datum der Statusaenderung
    # http://www.gbv.de/vgm/info/mitglieder/02Verbund/01Erschliessung/02Richtlinien/01KatRicht/0230.pdf
    $self->append( "001D", '0' => $hdate );

    # PCIA3: 0500 - Bibliographische Gattung und Status
    # http://www.gbv.de/vgm/info/mitglieder/02Verbund/01Erschliessung/02Richtlinien/01KatRicht/0500.pdf
    $self->append( "002@", '0' => $status );
}

=head2 to_string

Returns a string representation of the record for printing.

=cut

sub to_string() {
    my $self = shift;
    my @args = @_;

    my @lines = ();
    for my $field ( @{$self->{_fields}} ) {
        push( @lines, $field->to_string(@args) );
    }
    return join("", @lines);
}

=head2 normalized()

Returns record as a normalized string. Optionally adds prefix data at the beginning.

    print $record->normalized();
    print $record->normalized("##TitleSequenceNumber 1\n");

=cut

sub normalized() {
    my $self = shift;
    my $prefix = shift;
    $prefix = "" if (!$prefix);

    my @lines = ();
    for my $field ( @{$self->{_fields}} ) {
        push( @lines, $field->normalized() );
    }

    return "\x1D\x0A" . $prefix . join( "", @lines );
}

=head2 to_xml

Returns the record in XML format (not tested, nor official).

=cut

sub to_xml {
    my $self = shift;
    my @xml;
    push @xml, "<record>\n";
    for my $field ( @{$self->{_fields}} ) {
        push @xml, $field->to_xml();
    }
    push ( @xml , "</record>" );
    return join("", @xml) . "\n";
}

=head1 INTERNAL METHDOS

=head2 _get_regex

Get a complied regular expression

=cut

sub _get_regex {
    my $reg = shift;

    my $regex = $field_regex{ $reg };

    if (!defined $regex) {
        # Compile & stash
        $regex = qr/^$reg$/;
        $field_regex{ $reg } = $regex;
    }

    return $regex;
}

1;

__END__

=head1 TODO

The toString, to_xml, and normalized methods should be integrated
into L<PICA::Writer> or vice versa.

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007 by Verbundzentrale Goettingen (VZG) and Jakob Voss

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.
