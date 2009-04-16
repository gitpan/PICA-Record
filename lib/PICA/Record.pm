package PICA::Record;

=head1 NAME

PICA::Record - Perl extension for handling PICA+ records

=cut

use strict;
use utf8;
use base qw(Exporter);
our $VERSION = "0.46";

use POSIX qw(strftime);
use PICA::Field;
use PICA::Parser;
use Scalar::Util qw(looks_like_number);
use URI::Escape;
use Encode;
use Carp qw(croak);

=head1 DESCRIPTION

Module for handling PICA+ records as Perl objects.

=head1 INTRODUCTION

=head2 What is PICA+?

B<PICA+> is the internal data format of the Local Library System (LBS) and
the Central Library System (CBS) of OCLC, formerly PICA. Similar library
formats are the MAchine Readable Cataloging format (MARC) and the
Maschinelles Austauschformat für Bibliotheken (MAB). In addition to
PICA+ in CBS there is the cataloging format Pica3 which can losslessly
be convert to PICA+ and vice versa.

=head2 What is PICA::Record?

B<PICA::Record> is a Perl package that provides an API for PICA+ record
handling. The package contains a parser interface module L<PICA::Parser>
to parse PICA+ (L<PICA::PlainParser>) and PICA XML (L<PICA::XMLParser>).
Corresponding modules exist to write data (L<PICA::Writer> and
L<PICA::XMLWriter>). PICA+ data is handled in records (L<PICA::Record>)
that contain fields (L<PICA::Field>). To fetch records from databases
via SRU or Z39.50 there is the interface L<PICA::Source> and to access
a record store via CWS webcat interface there is L<PICA::Store>.

You can use PICA::Record for instance to:

=over 4

=item *
convert between PICA+ and PicaXML
=item *
process PICA+ records that you have downloaded with WinIBW 
=item *
download records in native format via SRU or Z39.50
=item*
store PICA+ records in a database

=back

=head1 COMMAND LINE USAGE

This module provides the scripts C<parsepica> and C<picawebcat> to
use most of the functionality on the command line without having
to deal with Perl code. Have a look at the documentation of this scripts.

=head1 SYNOPSIS

To get a deeper insight to the API have a look at the documentation,
the examples (directory C<examples>) and tests (directory C<t>). Here
are some additional two-liners:

  # create a field
  my $field = PICA::Field->new(
    "028A", "9" => "117060275", "d" => "Martin", "a" => "Schrettinger" );

  # create a record and add some fields (note that fields can be repeated)
  my $record = PICA::Record->new();
  $record->append( '044C', 'a' => "Perl", '044C', 'a' => "Programming", );

  # read all records from a file
  my @records = PICA::Parser->new->parsefile( $filename )->records();

  # read one record from a string
  my ($record) =  PICA::Parser->parsedata( $picadata, Limit => 1)->records();

  # get two fields of a record
  my ($f1, $f2) = $record->field( 2, "028B/.." );

  # extract some subfield values
  my ($given, $surname) = ($record->sf(1,'028A$d'), $record->sf(1,'028A$a'));

  # read records from a STDIN and print to STDOUT of field 003@ exists
  PICA::Parser->new->parsefile( \STDIN, Record => sub {
      my $record = shift;
      print $record->to_string() if $record->field('003@');
      return;
  });

  # print record in normalized format
  print $record->normalized();

  # write some records in XML to a file
  my $writer = PICA::Writer->new( $filename, format => 'xml' );
  $writer->write( @records );

=head1 METHODS

=head2 new ( [ ...data... | $filehandle ] )

Base constructor for the class. A single string will be parsed line by 
line into L<PICA::Field> objects, empty lines and start record markers will 
be skipped. More then one or non scalar parameters will be passed to 
C<append> so you can use the constructor in the same way:

  my $record = PICA::Record->new('037A','a' => 'My note');

If no data is given then it just returns a completely empty record. To load
PICA records from a file, see L<PICA::Parser>, to load records from a SRU
or Z39.50 server, see L<PICA::Source>. 

If you provide a file handle or L<IO::Handle>, the first record is read from
it. The following lines have same result:

  $record = PICA::Record->new( IO::Handle->new("< $filename") );
  ($record) = PICA::Parser->parsefile( $filename, Limit => 1 )->records(),
  open (F, "<", $plainpicafile); $record = PICA::Record->new( \*F ); close F;

=cut

sub new {
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
            my @l2 = split("\x1E", $first);
            if (@l2 > @lines) { # normalized
                @lines = @l2;
            }

            foreach my $line (@lines) {
                $line =~ s/^\x1D//;         # start of record
                next if $line =~ /^\s*$/;   # skip empty lines

                my $field = PICA::Field->parse($line);
                push (@{$self->{_fields}}, $field) if $field;
            }
        } elsif (ref($first) eq 'GLOB' or eval { $first->isa("IO::Handle") }) {
            PICA::Parser->parsefile( $first, Limit => 1, Field => sub {
                my $field = shift;
                push (@{$self->{_fields}}, $field); 
                return;
            });
        } else {
            $self->append(@_);
        }
    }

    return $self;
} # new()

=head2 copy ( )

Creates a clone of this record by copying all fields.

=cut

sub copy {
    my $self = shift;
    return PICA::Record->new( $self );
}

=head2 all_fields ( )

Returns an array of all the fields in the record. The array contains 
a C<PICA::Field> object for each field in the record. An empty array 
is returns if the record is empty.

=cut

sub all_fields() {
    my $self = shift;
    croak("You called all_fields() but you probably want field()") if @_;
    return @{$self->{_fields}};
}

=head2 field ( [ $limit, ] $tagspec(s) )

Returns a list of C<PICA::Field> objects with tags that
match the field specifier, or in scalar context, just
the first matching Field.

You may specify multiple tags and use regular expressions.

  my $field  = $record->field("021A","021C");
  my $field  = $record->field("009P/03");
  my @fields = $record->field("02..");
  my @fields = $record->field("039[B-E]");

If the first parameter is an integer, it is used as a limitation
of response size, for instance two get only two fields:

  my ($f1, $f2) = $record->field( 2, "028B/.." );

=cut

my %field_regex;

sub field {
    my $self = shift;
    my $limit = looks_like_number($_[0]) ? shift : 0;
    my @specs = @_;

    return unless @specs;
    my @list = ();

    for my $tag ( @specs ) {
        my $regex = _get_regex($tag);

        for my $maybe ( $self->all_fields ) {
            if ( $maybe->tag() =~ $regex ) {
                return $maybe unless wantarray;
                push( @list, $maybe );
                if ($limit > 0) {
                    return @list unless --$limit;
                }
            }
        }
    }

    return @list;
} # field()

=head2 f ( $tagspec(s) )

Shortcut for method C<field>.

=cut

sub f {
    return field(@_);
}

=head2 subfield ( [ $limit, ] [ $tagspec , $subfield ] | $spec )

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

If the first parameter is an integer, it is used as a limitation
of response size, for instance two get only two fields:

  my ($f1, $f2) = $record->subfield( 2, '028B/..$a' );

=cut

sub subfield {
    my $self = shift;
    my $limit = looks_like_number($_[0]) ? shift : 0;
    my ($tag, $subfield) = @_;
    return unless defined $tag;

    ($tag, $subfield) = split(/\$/,$tag) unless defined $subfield;
    croak("No subfields specified in '$tag'") if !defined $subfield;

    my @list = ();

    my $tag_regex = _get_regex($tag);
    for my $f ( $self->all_fields ) {
        if ( $f->tag() =~ $tag_regex ) {
            my @s = $f->subfield($subfield);
            if (@s) {
                return shift @s unless wantarray;
                if ($limit > 0) {
                    if (scalar @s >= $limit) {
                        push @list, @s[0..($limit-1)];
                        return @list;
                    }
                    $limit -= scalar @s;
                }
                push( @list, @s );
            }
        }
    }

    return @list;
} # subfield()

=head2 sf ( [ $tagspec , $subfield ] | $spec )

Shortcut for method C<subfield>.

=cut

sub sf {
    return subfield(@_);
}

=head2 values ( )

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

=head2 main_record ( )

Get the main record (level 0, all tags starting with '0').

=cut

sub main_record {
  my $self = shift;
  my @fields = $self->field("0...(/..)?");

  return PICA::Record->new(@fields);
}

=head2 local_records ( )

Get a list of local records (holdings, level 1 and 2).
Returns an array of L<PICA::Record> objects.

=cut

sub local_records {
  my $self = shift;

  my @holdings = ();
  my @fields = ();
  my $prevtag;

  foreach my $f (@{$self->{_fields}}) {
    next unless $f->tag =~ /^[^0]/;

    if ($f->tag =~ /^1/) {
        if ($prevtag && $prevtag =~ /^2/) {
            push @holdings, PICA::Record->new(@fields) if (@fields);
            @fields = ();
        }
    }

    push @fields, $f;
    $prevtag = $f->tag;
  }
  push @holdings, PICA::Record->new(@fields) if (@fields);
  return @holdings;
}


=head2 copy_records ( )

Get the copy records (level 2, all tags starting with '2').
Returns an array of L<PICA::Record> objects.

=cut

sub copy_records {
  my $self = shift;

  my @copies = ();
  my @fields = ();
  my $prevocc;

  foreach my $f (@{$self->{_fields}}) {
    next unless $f->tag =~ /^2...\/(..)/;

    if (!($prevocc && $prevocc eq $1)) {
      $prevocc = $1;
      push @copies, PICA::Record->new(@fields) if (@fields);
      @fields = ();
    }

    push @fields, $f;
  }
  push @copies, PICA::Record->new(@fields) if (@fields);
  return @copies;
}

=head2 is_empty ( )

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

    my $field = PICA::Field->new( '037A','a' => 'My note' );
    $record->append( $field );

is equivalent to

    $record->append('037A','a' => 'My note');

You can also append multiple fields with one call:

    my $field = PICA::Field->new('037A','a' => 'First note');
    $record->append( $field, '037A','a' => 'Second note' );

    $record->append(
        '037A', 'a' => '1st note',
        '037A', 'a' => '2nd note',
    );

Please note that passed L<PICA::Field> objects are not be copied but directly
used:

    my $field = PICA::Field->new('037A','a' => 'My note');
    $record->append( $field );
    $field->replace( 'a' => 'Your note' ); # Also changes $record's field!

You can avoid this by cloning fields or by using the appendif method:

    $record->append( $field->copy() );
    $record->appendif( $field );

You can also append copies of all fields of another record:

    $record->append( $record2 );

The append method returns the number of fields appended.

=cut

sub append {
    my $self = shift;
    # TODO: this method can be simplified by use of ->new (see appendif)

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

=head2 appendif ( ...fields or records... )

Optionally appends one or more fields to the end of the record. Parameters can
be L<PICA::Field> objects or parameters that are passed to C<PICA::Field->new>.

In contrast to the append method this method always copies values, it ignores
empty subfields and empty fields (that are fields without subfields or with
empty subfields only), and it returns the resulting PICA::Record object.

For instance this command will not add a field if C<$country> is undef or C<"">:

  $r->appendif( "119@", "a" => $country );

=cut

sub appendif {
    my $self = shift;
    my $append = PICA::Record->new( @_ );
    for my $field ( $append->all_fields ) {
        $field = $field->purged();
        push @{ $self->{_fields} }, $field if $field;
    }
    $self;
}

=head2 replace ( $tag, $field | @fieldspec )

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

=head2 sort ( )

Sort all fields. Most times the order of fields is not changed and
not relevant but sorted fields may be helpful for viewing records.

=cut

sub sort() {
    my $self = shift;

    @{$self->{_fields}} = sort {$a->tag() cmp $b->tag()} @{$self->{_fields}};
}

=head2 to_string ( [ %options ] )

Returns a string representation of the record for printing.
See also L<PICA::Writer> for printing to a file or file handle.

=cut

sub to_string() {
    my ($self, %args) = @_;

    $args{endfield} = "\n" unless defined($args{endfield});

    my @lines = ();
    for my $field ( @{$self->{_fields}} ) {
        push( @lines, $field->to_string(%args) );
    }
    return join('', @lines);
}

=head2 normalized ( [ $prefix ] )

Returns record as a normalized string. Optionally adds prefix data at the beginning.

    print $record->normalized();
    print $record->normalized("##TitleSequenceNumber 1\n");

See also L<PICA::Writer> for printing to a file or file handle.

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

=head2 to_xml ( [ %params ] )

Returns the record in PICA XML format. You can add an XML header with
header => 1 and a stylesheet with parameter xslt. Otherwise make sure
to have set the default namespace ('info:srw/schema/5/picaXML-v1.0')
to get valid PICA XML. See also L<PICA::XMLWriter>.

=cut

sub to_xml {
    my $self = shift;
    my %params = @_;
    my @xml;

    # TODO: combine in XMLWriter
    if ($params{header}) {
        push @xml, "<?xml version='1.0' encoding='UTF-8'?>\n";
        $params{collection} = 1;
    }
    if ($params{xslt}) {
        my $xslt = $params{xslt};
        $xslt =~ s/'/&apos/;
        push @xml, "<?xml-stylesheet type='text/xsl' href='$xslt'?>\n"
    }
    if ($params{collection}) {
        push @xml, "<collection xmlns='info:srw/schema/5/picaXML-v1.0'>\n";
    }

    push @xml, "<record>\n";
    for my $field ( @{$self->{_fields}} ) {
        push @xml, $field->to_xml();
    }
    push ( @xml , "</record>" );

    if ($params{collection}) {
        push @xml, "\n</collection>";
    }

    my $xml = join("", @xml) . "\n";
    return $xml;
}

=head2 add_headers ( [ %options ] )

Add header fields to a L<PICA::Record>. You must specify two named parameters
(C<eln> and C<status>). This method is experimental. There is no test whether 
the header fields already exist.

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

=head1 INTERNAL METHDOS

=head2 _get_regex ( $reg )

Get a complied regular expression.

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

=head1 SEE ALSO

At CPAN there are the modules L<MARC::Record>, L<MARC>, and L<MARC::XML> 
for MARC records and L<Encode::MAB2> for MAB records. The deprecated module
L<Net::Z3950::Record> also had a subclass L<Net::Z3950::Record::MAB> for MAB 
records. You should now better use L<Net::Z3950::ZOOM> which is also needed
if you query Z39.50 servers with L<PICA::Source>.

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007-2009 by Verbundzentrale Göttingen (VZG) and Jakob Voß

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.
