package PICA::Server;

=head1 NAME

PICA::Server - Server that can be searched for PICA+ records

=head1 SYNOPSIS

  my $server = PICA::Server->new(
      title => "My server",
      SRU => "http://my.server.org/sru-interface.cgi"
  );
  my $record = $server->getPPN('1234567890');

=cut

use strict;
use Carp;

use PICA::SRUSearchParser;
use LWP::UserAgent;

=head1 METHODS

=head2 new

Create a new Server. You can specify a title with C<title> and
the URL base of an SRU interface with C<SRU>.

=cut

sub new {
    my ($class, %params) = @_;
    $class = ref $class || $class;

    my $self = {
        title => $params{title} ? $params{title} : "Untitled",
        SRU => $params{SRU} ? $params{SRU} : undef              # SRU interface
    };

    if ($self->{SRU} and not $self->{SRU} =~ /[\?&]$/) {
        $self->{SRU} .= ($self->{SRU} =~ /\?/) ? '&' : '?';
    }

    bless $self, $class;
}

=head2 getPPN

Get a record specified by its PPN. Returns a L<PICA::Record> object or undef.

=cut

sub getPPN {
    my ($self, $ppn) = @_;

    croak("No SRU interface defined") unless $self->{SRU};
    croak("Not a PPN: $ppn") unless $ppn =~ /^[0-9]+[0-9Xx]$/;

    my $query = "pica.ppn\%3D$ppn"; # CQL query

    my $ua = LWP::UserAgent->new( agent => 'PICA::Server SRU-Client/0.1');

    my $url = $self->{SRU} . "query=" . $query . "&recordSchema=pica&version=1.1&operation=searchRetrieve";
    # print "$url\n";

    my $request = HTTP::Request->new(GET => $url);
    my $response = $ua->request($request);
    if ($response->is_success) {
        my $xml = $response->decoded_content();
        my $record;
        my $parser = PICA::SRUSearchParser->new( Record=>sub { $record = shift; } );
        $parser->parseResponse($xml);
        return $record;
    } else {
        croak("SRU Request failed: $url");
    }
}

=head2 cqlQuery

Perform a CQL query and return the XML data. If you supply an additional 
hash with Record and Field handlers, it is used for parsing the PICA+ 
records in the results with a L<PICA::SRUSearchParser>. Afterwards the parser
is returned. If only one parameter is given, the full XML response is returned.

=cut

sub cqlQuery {
    my ($self, $cql, %handlers) = @_;

    my $ua = LWP::UserAgent->new( agent => 'PICA::Server SRU-Client/0.1');
    $cql = url_encode($cql); #url_unicode_encode($cql);

    my $options = "";
    my $url = $self->{SRU} . "query=" . $cql . $options . "&recordSchema=pica&version=1.1&operation=searchRetrieve";
    # print "$url\n"; # TODO: logging

    # TODO: implement a query loop for long result sets
    my $request = HTTP::Request->new(GET => $url);
    my $response = $ua->request($request);
    if ($response->is_success) {
        my $xml = $response->decoded_content();
        if (%handlers) {
            my $parser = PICA::SRUSearchParser->new( %handlers ); # Record=>sub { my $record = shift; print "##\n";}  );
            $parser->parseResponse($xml);
            return $parser;
        } else {
            return $xml;
        }
    } else {
        croak("SRU Request failed: $url");
    }
}

=head1 UTILITY FUNCTIONS

=head2 url_encode

Returns the fully URL-encoded version of the given string.
It does not convert space characters to '+' characters.
This method is based on L<CGI::Utils> by Don Owens.

=cut

sub url_encode {
    my $url = shift;
    $url =~ s{([^A-Za-z0-9_\.\*])}{sprintf("%%%02x", ord($1))}eg;
    return $url;
}

=head2 url_unicode_encode

Returns the fully URL-encoded version of the given string as
unicode characters.  It does not convert space characters to 
'+' characters. This method is based on L<CGI::Utils> by Don Owens.

=cut

sub url_unicode_encode {
    my $url = shift;
    $url =~ s{([^A-Za-z0-9_\.\*])}{sprintf("%%u%04x", ord($1))}eg;
    return $url;
}

1;

__END__

=head1 TODO

Better error handling is needed, for instance of the server is 
"System temporarily unavailable".

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007 by Verbundzentrale Göttingen (VZG) and Jakob Voss

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.

Please note that these module s not product of or supported by the 
employers of the various contributors to the code nor by OCLC PICA.

