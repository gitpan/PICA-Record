package PICA::Field;

=head1 NAME

PICA::Field - Perl extension for handling PICA+ fields

=cut

use strict;
use utf8;

use base qw(Exporter);
our $VERSION = "0.45";

use Carp qw(croak);
our @EXPORT = qw(parse_pp_tag);

use constant SUBFIELD_INDICATOR => "\x1F"; # 31
use constant START_OF_FIELD     => "\x1E"; # 30
use constant END_OF_FIELD       => "\x0A"; # 10

use constant FIELD_TAG_REGEXP => qr/[012][0-9][0-9][A-Z@]$/;
use constant FIELD_OCCURRENCE_REGEXP => qr/[0-9][0-9]$/;
use constant SUBFIELD_CODE_REGEXP => qr/^[0-9a-zA-Z]$/;

=head1 SYNOPSIS

  use PICA::Field;
  my $field = PICA::Field->new( '028A',
    '9' => '117060275',
    '8' => 'Martin Schrettinger'
  );

  $field->add( 'd' => 'Martin', 'a' => 'Schrettinger' );
  $field->update( "8", "Schrettinger, Martin" );

  print $field->normalized();
  print $field->to_xml();

=head1 DESCRIPTION

Defines PICA+ fields for use in the PICA::Record module.

=head1 EXPORT

The method C<parse_pp_tag> is exported.

=head1 METHODS

=head2 new ( [...] )

The constructor, which will return a C<PICA::Field> object or croak on error.
You can call the constructor with a tag and a list of subfields:

  PICA::Field->new( '028A',
    '9' => '117060275',
    '8' => 'Martin Schrettinger'
  );

With a string of normalized PICA+ data of one field:

  PICA::Field->new("\x1E028A \x1F9117060275\x1F8Martin Schrettinger\x0A');

With a string of readable PICA+ data:

  PICA::Field->new('028A $9117060275$8Martin Schrettinger');

=cut


sub new($) {
    my $class = shift;
    $class = ref($class) || $class;

    my $tag = shift;
    $tag or croak( "No tag provided." );

    if (not @_) { # empty field
        return PICA::Field->parse($tag); 
    }

    my ($occurrence, $tagno) = parse_pp_tag($tag);

    defined $tagno or croak( "\"$tag\" is not a valid tag." );

    my $self = bless {
        _tag => $tagno,
        _occurrence => $occurrence
    }, $class;

    $self->add(@_);

    return $self;
}


=head2 copy ( $field )

Creates and returns a copy of this object.

=cut

sub copy {
    my $self = shift;

    my $tagno = $self->{_tag};
    my $occurrence = $self->{_occurrence};

    my $copy = bless {
        _tag => $tagno,
        _occurrence => $occurrence,
    }, ref($self);

    $copy->add( @{$self->{_subfields}} );

    return $copy;
}

=head2 parse ( $string, [, \&tag_filter_func ] )

The constructur will return a PICA::Field object based on data that is 
parsed if null if the filter dropped the field. Dropped fields will not 
be parsed so they are also not validated.

The C<$tag_filter_func> is an optional reference to a user-supplied 
function that determines on a tag-by-tag basis if you want the tag to 
be parsed or dropped. The function is passed the tag number (including 
occurrence), and must return a boolean. 

For example, if you only want to 021A fields, try this:

The filter function can be used to select only required fields

   sub filter {
        my $tagno = shift;
        return $tagno eq "021A";
    }
    my $field = PICA::Field->parse( $string, \&filter );

=cut

sub parse($) {
    my $class = shift;
    $class = ref($class) || $class;

    my $data = shift;
    my $tag_filter_func = shift;

    my $START_OF_FIELD = START_OF_FIELD;

    # TODO: better manage different parsing modes (normalized, plain, WinIBW...)
    my $END_OF_FIELD = END_OF_FIELD;
    $END_OF_FIELD = qr/[\x0A\x0D]+/;

    $data =~ s/^$START_OF_FIELD//;
    $data =~ s/$END_OF_FIELD$//;

    my $self = bless {}, $class;

    my ($tagno, $subfields) = ($data =~ /([^\$\x1F\x83\s]+)\s?(.*)/);

    return if $tag_filter_func and !$tag_filter_func->($tagno);

    # TODO: better manage different parsing modes (normalized, plain, WinIBW...)
    my $sfreg;
    my $sf = substr($subfields, 0, 1);
    if ($sf eq "\x1F") { $sfreg = '\x1F'; }
    elsif ( $sf eq '$' ) { $sfreg = '\$'; }
    elsif( $sf eq "\x83" ) { $sfreg = '\x83'; }
    elsif( $sf eq "\x9f" ) { $sfreg = '\x9f'; }
    else {
        croak("No or not allowed subfield indicator (ord: " . ord($sf) . ") specified");
    }
    $sfreg = '('.$sfreg.'[0-9a-zA-Z])';

    my @sfields = split($sfreg, $subfields);
    shift @sfields;

    my @subfields = ();
    my ($value, $code);
    while (@sfields) {
        $code = shift @sfields;
        $code = substr($code, 1);
        $value = shift @sfields;
        $value =~ s/\$\$/\$/g if $sf eq '$';
        push(@subfields, ($code, $value));
    }

    return $self->new($tagno, @subfields);
}

=head2 tag ( [$tag] )

Returns the PICA+ tag and occurrence of the field. Optionally sets tag (and occurrence) to a new value.

=cut

sub tag {
    my $self = shift;
    my $tag = shift;

    if (defined $tag) {
        my ($occurrence, $tagno) = parse_pp_tag($tag);
        defined $tagno or croak( "\"$tag\" is not a valid tag." );

        $self->{_tag} = $tagno;
        $self->{_occurrence} = $occurrence;
    }

    return $self->{_tag} . ($self->{_occurrence} ?  ("/" . $self->{_occurrence}) : "");
}

=head2 level ( )

Returns the level (0: main, 1: local, 2: copy) of this field.

=cut

sub level {
    my $self = shift;
    return substr($self->{_tag},0,1);
}

=head2 sf ( [ $code(s) ] )

Shortcut for method C<subfield>.

=cut

sub sf {
    return subfield(@_);
}

=head2 subfield ( [ $code(s) ] )

Return selected or all subfield values. If you specify 
one ore more subfield codes, only matching subfields are 
returned. When called in a scalar context returns only the
first (matching) subfield. You may specify multiple subfield codes:

    my $subfield = $field->subfield( 'a' );   # first $a
    my $subfield = $field->subfield( 'acr' ); # first of $a, $c, $r
    my $subfield = $field->subfield( 'a', 'c', 'r' ); # the same

    my @subfields = $field->subfield( 'a' );
    my @all_subfields = $field->subfield();

If no matching subfields are found, C<undef> is returned in a scalar
context or an empty list in a list context.

Remember that there can be more than one subfield of a given code!

=cut

sub subfield {
    my $self = shift;
    my $codes = join('',@_);
    $codes = $codes eq '' ? '.' : "[$codes]";
    $codes = qr/$codes/;

    my @list;
    my @data = @{$self->{_subfields}};

    for ( my $i=0; $i < @data; $i+=2 ) {
        next unless $data[$i] =~ $codes;
        if ( wantarray() ) {
            push( @list,  $data[$i+1] );
        } else {
            return $data[$i+1];
        }
    }

    return @list;
}

=head2 content ( [ $code(s) ] )

Return selected or all subfields as an array of arrays. If you specify 
one ore more subfield codes, only matching subfields are returned. See
the C<subfield> method for more examples.

This shows the subfields from a 021A field:

        [
          [ 'a', '@Traité de documentation' ],
          [ 'd', 'Le livre sur le livre ; Théorie et pratique' ],
          [ 'h', 'Paul Otlet' ]
        ]

=cut

sub content {
    my $self = shift;
    my $codes = join('',@_);
    $codes = $codes eq '' ? '.' : "[$codes]";
    $codes = qr/$codes/;

    my @list;
    my @data = @{$self->{_subfields}};

    for ( my $i=0; $i < @data; $i+=2 ) {
        next unless $data[$i] =~ $codes;
        push( @list, [ $data[$i], $data[$i+1] ] );
    }

    return @list;
}

=head2 add ( $code, $text [, $code, $text ...] )

Adds subfields to the end of the subfield list.

    $field->add( 'c' => '1985' );

Returns the number of subfields added.

=cut

sub add(@) {
    my $self = shift;
    my $nfields = @_ / 2;

    ($nfields >= 1)
        or croak( "Missing at least one subfield" );

    for my $i ( 1..$nfields ) {
        my $offset = ($i-1)*2;
        my $code = $_[$offset];

        croak( "Subfield code \"$code\" is not a valid subfield code" )
            if !($code =~ SUBFIELD_CODE_REGEXP);
    }

    push( @{$self->{_subfields}}, @_ );

    return $nfields;
}

=head2 update ( )

Allows you to change the values of the field. You can update indicators
and subfields like this:

  $field->update( a => 'Little Science, Big Science' );

If you attempt to update a subfield which does not currently exist in the field,
then a new subfield will be appended to the field. If you don't like this
auto-vivification you must check for the existence of the subfield prior to
update.

  if ( $field->subfield( 'a' ) ) {
    $field->update( 'a' => 'Cryptonomicon' );
  }

Note: when doing subfield updates be aware that C<update()> will only
update the first occurrence. If you need to do anything more complicated
you will probably need to create a new field and use C<replace()>.

Returns the number of items modified.

=cut

sub update {
    my $self = shift;

    my @data = @{$self->{_subfields}};
    my $changes = 0;

    while ( @_ ) {
        my $code = shift;
        my $val = shift;

        croak( "Subfield code \"$code\" is not a valid subfield code" )
            if !($code =~ SUBFIELD_CODE_REGEXP);

            my $found = 0;

        ## update existing subfield
        for ( my $i=0; $i<@data; $i+=2 ) {
            if ($data[$i] eq $code) {
                $data[$i+1] = $val;
            $found = 1;
            $changes++;
            last;
            }
        }

        ## append new subfield
        if ( !$found ) {
            push( @data, $code, $val );
            $changes++;
        }
    }

    ## synchronize our subfields
    $self->{_subfields} = \@data;
    return($changes);
}

=head2 replace ( $field | ... )

Allows you to replace an existing field with a new one. You may pass a
C<PICA::Field> object or parameters for a new field to replace the
existing field with. Replace does not return a meaningful or reliable value.

=cut

sub replace {
    my $self = shift;
    my $new;

    if (@_ and ref($_[0]) eq "PICA::Field") {
        $new = shift;
    } else {
        $new = PICA::Field->new(@_);
    }

    %$self = %$new;
}

=head2 empty_subfields ( )

Returns a list of all codes of empty subfields.

=cut

sub empty_subfields {
    my $self = shift;

    my @list;
    my @data = @{$self->{_subfields}};

    while ( defined( my $code = shift @data ) ) {
        push (@list, $code) if shift @data eq "";
    }

    return @list;
}

=head2 is_empty ( )

Test whether there are no subfields or all subfields are empty.

=cut

sub is_empty() {
    my $self = shift;

    my @data = @{$self->{_subfields}};

    while ( defined( my $code = shift @data ) ) {
        return 0 if shift @data ne "";
    }

    return 1;
}

=head2 normalized ( [$subfields] )

Returns the field as a string. The tag number, occurrence and 
subfield indicators are included. 

If C<$subfields> is specified, then only those subfields will be included.

=cut

sub normalized() {
    my $self = shift;
    my $subfields = shift;

    return $self->to_string( 
      subfields => $subfields,
      startfield => START_OF_FIELD,
      endfield => END_OF_FIELD,
      startsubfield => SUBFIELD_INDICATOR
    );
}

=head2 to_string ( [ %params ] )

Returns a pretty string for printing.

Returns the field as a string. The tag number, occurrence and 
subfield indicators are included. 

If C<subfields> is specified, then only those subfields will be included.

Fields without subfields return an empty string.

=cut

sub to_string() {
    my $self = shift;
    my %args = @_;

    my $subfields = defined($args{subfields}) ? $args{subfields} : '';
    my $startfield = defined($args{startfield}) ? $args{startfield} : '';
    my $endfield  = defined($args{endfield}) ? $args{endfield} : "\n";
    my $startsubfield = defined($args{startsubfield}) ? $args{startsubfield} : '$';

    my @subs;

    my $subs = $self->{_subfields};
    my $nfields = @$subs / 2;

    for my $i ( 1..$nfields ) {
        my $offset = ($i-1)*2;
        my $code = $subs->[$offset];
        my $text = $subs->[$offset+1];
        if (!$subfields || $code =~ /^[$subfields]$/) {
            $text =~ s/\$/\$\$/g if $startsubfield eq '$';
            push( @subs, $code.$text ) 
        }
    } # for

    return "" unless @subs; # no subfields => no field

    my $occ = '';
    $occ = "/" . $self->{_occurrence} if defined $self->{_occurrence};

    return $startfield .
           $self->{_tag} . $occ . ' ' .
           $startsubfield . join( $startsubfield, @subs ) .
           $endfield;
}

=head2 to_xml ( )

Returns the field in XML format:

  <datafield tag='....' occurrence='..'>
    <subfield code='.'>....</subfield>
    ...
  </datafield>

Make sure to have set the default namespace ('info:srw/schema/5/picaXML-v1.0')
to get valid PICA XML. See also L<PICA::XMLWriter>.

=cut

sub to_xml {
    my $self = shift;

    my $xml = "<datafield tag='" . $self->{_tag} . "'";
    $xml .= " occurrence='" . $self->{_occurrence} . "'" if defined $self->{_occurrence};
    $xml .= ">\n";

    my $subs = $self->{_subfields};
    my $nfields = @$subs / 2;

    return "" unless $nfields; # field without subfields

    for my $i ( 1..$nfields ) {
        my $offset = ($i-1)*2;
        my $code = $subs->[$offset];
        my $text = $subs->[$offset+1];
        $xml .= "  <subfield code='$code'>";
        $text =~ s/&/&amp;/g;
        $text =~ s/</&lt;/g;
        $xml .= $text; # TODO: character encoding (?)
        $xml .= "</subfield>\n";
    }
    $xml .= "</datafield>\n";

    return $xml;
}

=head1 STATIC METHODS

=head2 parse_pp_tag tag ( $tag )

Tests whether a string can be used as a tag/occurrence specifier. A tag
indicator consists of a 'type' (00-99) and an 'indicator' (A-Z and @),
both conflated as the 'tag', and an optional occurrence (00-99). This
method returns a list of two values: occurrence and tag (this order!).
This method can be used to parse and test tag specifiers this way:

  ($occurrence, $tag) = parse_pp_tag( $t );
  parse_pp_tag( $t ) or print STDERR "Not a valid tag: $t\n";

=cut

sub parse_pp_tag {
    my $tag = shift;

    my ($tagno, $occurrence) = split ('/', $tag);
    undef $tagno unless $tagno =~ FIELD_TAG_REGEXP;
    undef $occurrence unless defined $occurrence and $occurrence =~ FIELD_OCCURRENCE_REGEXP;

    return ($occurrence, $tagno);
}

1;

__END__

=head1 SEE ALSO

This module is mainly based on L<MARC::Field> by Andy Lester.

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007-2009 by Verbundzentrale Göttingen (VZG) and Jakob Voß

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.
