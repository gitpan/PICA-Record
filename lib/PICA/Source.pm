package PICA::Source;

=head1 NAME

PICA::Source - Data source that can be searched for PICA+ records

=head1 SYNOPSIS

  my $server = PICA::Source->new(
      title => "My server",
      SRU => "http://my.server.org/sru-interface.cgi"
  );
  my $record = $server->getPPN('1234567890');

=cut

use strict;
use Carp;

use PICA::PlainParser;
use PICA::SRUSearchParser;
use LWP::UserAgent;

use vars qw($VERSION);
$VERSION = "0.38";

=head1 METHODS

=head2 new

Create a new Server. You can specify a title with C<title> and
the URL base of an SRU interface with C<SRU> or a Z39.50 server
with C<Z3950>.

=cut

sub new {
    my ($class, %params) = @_;
    $class = ref $class || $class;

    my $self = {
        title => $params{title} ? $params{title} : "Untitled",
        SRU => $params{SRU} ? $params{SRU} : undef,
        Z3950 => $params{Z3950} ? $params{Z3950} : undef,
        user => $params{user} ? $params{user} : undef,
        password => $params{password} ? $params{password} : undef,
        prev_record => undef
    };

    if ($self->{SRU} and not $self->{SRU} =~ /[\?&]$/) {
        $self->{SRU} .= ($self->{SRU} =~ /\?/) ? '&' : '?';
    }

    bless $self, $class;
}

=head2 getPPN

Get a record specified by its PPN. Returns a L<PICA::Record> object or undef.
Only available for SRU at the moment.

=cut

sub getPPN {
    my ($self, $ppn) = @_;

    croak("No SRU interface defined") unless $self->{SRU};
    croak("Not a PPN: $ppn") unless $ppn =~ /^[0-9]+[0-9Xx]$/;

    my $query = "pica.ppn\%3D$ppn"; # CQL query

    my $ua = LWP::UserAgent->new( agent => 'PICA::Source SRU-Client/0.1');

    my $url = $self->{SRU} . "query=" . $query . "&recordSchema=pica&version=1.1&operation=searchRetrieve";
    # print "$url\n";

    my $request = HTTP::Request->new(GET => $url);
    my $response = $ua->request($request);
    if ($response->is_success) {
        my $xml = $response->decoded_content();
        # create SRUSearchParser only once because of memory leak
        if (!$self->{sruparser}) {
            $self->{sruparser} = PICA::SRUSearchParser->new(
                Record=>sub { $self->{prev_record} = shift; }
            );
        }
        $self->{sruparser}->parseResponse($xml);
        return $self->{prev_record};
    } else {
        croak("SRU Request failed: $url");
    }
}

=head2 cqlQuery

Perform a CQL query (SRU). If only one parameter is given, the full 
XML response is returned and you can parse it with L<PICA::SRUSearchParser>.

If you supply an additional hash with Record and Field handlers
(see L<PICA::Parser>) this handlers are used. Afterwards the parser
is returned.

=cut

sub cqlQuery {
    my ($self, $cql, %handlers) = @_;

    croak("No SRU interface defined") unless $self->{SRU};
    my $ua = LWP::UserAgent->new( agent => 'PICA::Source SRU-Client/0.1');
    $cql = url_encode($cql); #url_unicode_encode($cql);

    my $options = "";
    my $url = $self->{SRU} . "query=" . $cql . $options . "&recordSchema=pica&version=1.1&operation=searchRetrieve";
    # print "$url\n"; # TODO: logging

    # TODO: implement a query loop for long result sets
    my $request = HTTP::Request->new(GET => $url);
    my $response = $ua->request($request);
    if ($response->is_success) {
        my $xml = $response->decoded_content();
        # TODO: the SRUSearchParser may not be free'd (memory leak)?
        # TODO: Supply a PICA::SRUSearchParser or another PICA::Parser (?)
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

=head2 z3950Query

Perform a Z39.50 query via L<ZOOM>.If only one parameter is given, the 
L<ZOOM::ResultSet> is returned and you can parse it with a L<PICA::PlainParser>:

    my $n = $rs->size();
    for my $i (0..$n-1) {
        $parser->parsedata($rs->record($i)->raw());
    }

If you supply an additional hash with Record and Field handlers
(see L<PICA::Parser>) this handlers are used. Afterwards the parser
is returned.

=cut

sub z3950Query {
    my ($self, $query, %handlers) = @_;

    croak("Please load package ZOOM to use Z39.50!")
        unless defined $INC{'ZOOM.pm'};
    croak("No Z3950 interface defined") unless $self->{Z3950};
    croak("Z3950 interface have host and database") 
        unless $self->{Z3950} =~ /^(tcp:|ssl:)?([^\/:]+)(:[0-9]+)?\/(.*)/;

    my $options = new ZOOM::Options();
    $options->option( preferredRecordSyntax => "picamarc" );
    $options->option( user => $self->{user} ) if defined $self->{user};
    $options->option( password => $self->{password} ) if defined $self->{password};

    my ($conn, $rs);
    eval {
        $conn = ZOOM::Connection->create( $options );
        $conn->connect( $self->{Z3950} );
    };
    eval { $rs = $conn->search_pqf($query); } unless $@;
    if ($@) {
        croak("Z39.50 error " . $@->code(), ": ", $@->message());
    }

    if (%handlers) {
        my $parser = PICA::PlainParser->new( %handlers, Proceed=>1 );
        my $n = $rs->size();
        for my $i (0..$n-1) {
            my $raw;
            eval {
                $raw = $rs->record($i)->raw();
            };
            if ($@) {
                croak("Z39.50 error " . $@->code(), ": ", $@->message());
            }
            #print "$raw\n";
            $parser->parsedata($raw);
        }
        return $parser;
    } else {
        return $rs;
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
"System temporarily unavailable". PICA::SRUSearchParser should 
only be created once.

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007 by Verbundzentrale Goettingen (VZG) and Jakob Voss

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.

