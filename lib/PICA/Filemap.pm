package PICA::Filemap;

=head1 NAME

PICA::Filemap - Map between files and record ids

=cut

use strict;
use utf8;
use base qw(Exporter);
our $VERSION = "0.10";

use URI::Escape qw(uri_escape_utf8 uri_unescape);
use Encode qw(decode_utf8);
use IO::File; 
use Carp qw(croak);

=head1 DESCRIPTION

Experimental module to map between files and record ids.

=head1 METHODS

=head2 new ( $mapfile )

Opens a new filemap with a given filename or handle (L<IO::Handle>).
Use '-' for STDIN/STDOUT. The map is not read or written unless you 
call it with the methods read/write.

=cut

sub new {
    my $class = shift;
    my $file = shift; # TODO
    croak("please provide a map file") unless defined $file;

    my $self = bless {
        'map' => { } # filename => { id => id, timestamp => timestamp }
        # filenames are stored as unencoded UTF8 strings
    };

    if (ref($file) eq "GLOB" or eval { $file->isa("IO::Handle") }) {
        $self->{file} = $file;
    } else {
        $self->{filename} = $file;
    }

    return $self;
}

=head2 parseline ( $line )

Parses a map file line into timestamp, filename, and id and returns this
three values in an array. Timestamp and id can be undef. A map file line
contains one to three whitespace seperated values per line:

  filename
  filename id
  timestamp filename
  timestamp filename id

A timestamp must be an ISO 8601 timestamp that matches YYYY-MM-DDThh:mm:ss.
If a filename contains a '%' character, it is URI unescaped. Comments can
be added starting with '#'. If a line is empty or could not be parsed, 
the filename element in the return list is undef.

=cut

sub parseline {
    my ($self, $line) = @_;
    chomp $line;
    $line =~ s/^\s*|\s*(#.*)?$//g;
    return unless $line ne "";

    my @fields = split /\s+/, $line;
    my $timestamp = shift @fields 
        if $fields[0] =~ /\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d/;
    my $filename = unencoded_path( shift @fields );
    my $id = shift @fields;

    return ($timestamp, $filename, $id);
}

=head2 createline ( [ $timestamp, ] $filename [, $id ] )

Create a map file line with timestamp (optional), filename, and id (optional).
Filenames are URI escaped.

=cut

sub createline {
    my ($self, $timestamp, $filename, $id) = @_;
    return "" unless defined $filename;
    $filename = encode_path($filename);
    my $line = defined $timestamp ? "$timestamp " : "";
    $line .= $filename;
    $line .= " $id" if defined $id;
    return $line;
}

=head2 write ( )

Write the map to a file or file handle. Returns the number of written entries.

=cut

sub write {
    my $self = shift;
    # TODO: open if not exist (filename)

    my $fh = $self->{file};
    if (not defined $fh) {
        if ( $self->{filename} eq "-" ) {
            $fh = \*STDOUT;
        } else {
            $fh = IO::File->new($self->{filename},"w");
            croak("Failed to open ".$self->{filename}) unless defined $fh;
        }
    }

    my $count = 0; # TODO: sort by timestamp
    foreach my $filename (keys %{$self->{"map"}}) {
        my $timestamp = $self->{"map"}->{$filename}->{timestamp};
        my $id = $self->{"map"}->{$filename}->{id};
        my $line = $self->createline($timestamp,$filename,$id);
        if ($line) {
            print $fh "$line\n";
            $count++;
        }
    }

    return $count;
}

=head2 read ( )

Read the map from a file and file handle. Returns the number of read entries.

=cut

sub read {
    my $self = shift;

    my $fh = $self->{file};
    if (not defined $fh) {
        if ( $self->{filename} eq "-" ) {
            $fh = \*STDIN;
        } else {
            $fh = IO::File->new($self->{filename},"r");
            croak("Failed to open ".$self->{filename}) unless defined $fh;
        }
    }

    my $count = 0;
    while (<$fh>) {
        my ($timestamp, $filename, $id) = $self->parseline($_);
        if ( defined $filename ) {
            my $map = {};
            $map->{id} = $id if defined $id;
            $map->{timestamp} = $timestamp if defined $timestamp;
            $self->{"map"}->{$filename} = $map;
            $count++;
        }
    }

    return $count;
}

=head2 size ( )

Return the number of files in this map.

=cut

sub size {
    my $self = shift;
    return scalar keys %{ $self->{'map'} };
}

=head2 file2id ( $filename )

Get the id of a file or undef if the file or its id was not found in the map.

=cut

sub file2id {
    my $self = shift;
    my $filename = shift;
    my $file = $self->{"map"}->{ unencoded_path($filename) };
    return unless defined $file;
    return $file->{id};
}

=head2 id2file ( $id )

Get the file of a given id or undef if the id was not found in the map.

=cut

sub id2file {
    my $self = shift;
    my $id = shift;
    while (my ($filename, $entry) = each %{$self->{'map'}}) {
        if ($entry->{id} and $entry->{id} eq $id) {
            return $filename; # TODO URI-encode/decode
        }
    }
    return undef;
}

=head2 files ( [ $id_or_filename [, $id_or_filename...] ] )

Return list of all files in this map. In addition you can 
filter the list by ids/and or file.

=cut

sub files {
    my $self = shift;
    if (@_) { # TODO: improve performance
        my @files;
        foreach (@_) {
            my $filename = unencoded_path($_);
            if (defined $self->{"map"}->{$filename}) {
                push @files, $filename;
            } else {
                $filename = $self->id2file($filename);
                push @files, $filename if $filename;
            }
        }
        return @files;
    } else {
        # return all files
        return keys %{$self->{"map"}}; 
    }
}

=head2 ids ( [ $id_or_filename [, $id_or_filename...] ] )

Return a list of all ids in this map or all ids of a given
set of ids and/or filenames.

=cut

sub ids {
    my $self = shift;
    my %ids;
    foreach my $filename ( keys %{$self->{"map"}} ) {
        my $id = $self->{"map"}->{$filename}->{id};
        $ids{$id} = $id if defined $id;
    }
    # TODO: filter
    return keys %ids;
}

=head2 outdated

Return whether a given file in the map has been changed 
since the last timestamp. A file without timestamp is
always outdated.

=cut

sub outdated {
    my ($self, $filename) = @_;

    my $file = $self->{"map"}->{$filename};
    return 0 unless $file;
    return 1 unless $file->{timestamp};

    my @stat = stat $filename; # TODO: URI-encode/decode
    return unless @stat;

    return timestamp($stat[9]) ge $file->{timestamp};
}

=head2 create ( $filename, $id )

Add a file in the map with given filename and id.

=cut

sub create {
    my ($self, $filename, $id) = @_;
    $self->{'map'}->{$filename} = {
        'timestamp' => timestamp(),
        'id' => $id
    }
}

=head2 update ( $filename, $id )

Update a file in the map with given filename and id.

=cut

sub update {
    my ($self, $filename, $id) = @_;
    $self->delete($id);
    $self->create($filename,$id);
}

=head2 delete ( $id )

Remove a file from the map by given id.

=cut

sub delete {
    my ($self, $id) = @_;
    my @files = grep {
        my $map = $self->{'map'};
        defined $map->{$_}->{id} ? $map->{$_}->{id} eq $id : 0;
    } keys %{ $self->{"map"} };
    foreach (@files) {
        delete $self->{'map'}->{$_};
    }
}

=head2 clean ( )

Clean the map by removing all files that do not exist anymore.
Returns a list of removed files.

=cut

sub clean {
    my $self = shift;
    # TODO: support filter
    my @files = grep { 
        not (-f $_ or -f unencoded_path($_))
    } keys %{ $self->{'map'} };
    foreach (@files) {
        delete $self->{'map'}->{$_};
    }
    return @files;
}

=head2 add ( $file(s) )

Add one or more files to the map if they do exist and are not
already in the map. Returns a list of added files.

=cut

sub add {
    my $self = shift;
    # TODO: support filter
    my @files = grep { 
        (-f $_ or -f unencoded_path($_)) and not $self->{'map'}->{$_}; 
    } @_;
    foreach (@files) {
        $self->{'map'}->{$_} = { };
    }
    return @files;
}

=head1 Utility function

=head2 unencoded_path ( $string )

Unencode a full path.

=cut

sub unencoded_path {
    my $string = shift;
    if (defined $string and $string =~ /^(.*[\/])([^\/]+)$/) {
        return $1 . unencoded($2);
    } else {
        return unencoded($string);
    }
}

=head2 unencoded ( $string )

Remove URI-encoding (if '%' in the name) and return in UTF-8.

=cut

sub unencoded {
    my $string = shift;
    if (defined $string and $string =~ /%/) { # TODO: better check
        return decode_utf8( uri_unescape($string) );
    }
    return $string
}

=head2 encode_path ( $string )

Encode a full path.

=cut

sub encode_path {
    my $string = shift;
    if (defined $string and $string =~ /^(.*[\/])([^\/]+)$/) {
        return $1 . uri_escape_utf8($2);
    } else {
        return uri_escape_utf8($string);
    }
}


=head2 timestamp ( [ $time ] ) 

Returns an ISO 8601 timestamp of the form YYYY-MM-DDThh:mm:ss.

=cut

sub timestamp {
    my $time = shift || time;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
    return sprintf "%4d-%02d-%02dT%02d:%02d:%02d",
                   $year+1900,$mon+1,$mday,$hour,$min,$sec;
}

1;

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007-2009 by Verbundzentrale Göttingen (VZG) and Jakob Voß

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.
