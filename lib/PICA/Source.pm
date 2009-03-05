package PICA::Source;

=head1 NAME

PICA::Source - Data source that can be queried for PICA+ records

=cut

use strict;
use utf8;
our $VERSION = "0.42";

=head1 SYNOPSIS

  my $server = PICA::Source->new(
      title => "My server",
      SRU => "http://my.server.org/sru-interface.cgi"
  );
  my $record = $server->getPPN('1234567890');

Instead or in addition to SRU you can use Z39.50 and unAPI.

=cut

use Carp qw(croak);
use PICA::PlainParser;
use PICA::SRUSearchParser;
use LWP::UserAgent;

=head1 METHODS

=head2 new ( [ %params ] )

Create a new Server. You can specify a title with C<title> and
the URL base of an SRU interface with C<SRU>, a Z39.50 server
with C<Z3950> and an unAPI base url with C<unAPI>.

=cut

sub new {
    my ($class, %params) = @_;
    $class = ref $class || $class;

    my $self = {
        title => $params{title} ? $params{title} : "Untitled",
        SRU => $params{SRU} ? $params{SRU} : undef,
        Z3950 => $params{Z3950} ? $params{Z3950} : undef,
        unAPI => $params{unAPI} ? $params{unAPI} : undef,
        user => $params{user} ? $params{user} : undef,
        password => $params{password} ? $params{password} : undef,
        prev_record => undef,
        # TODO: pass handler parameter or Parser?
    };

    if ($self->{SRU} and not $self->{SRU} =~ /[\?&]$/) {
        $self->{SRU} .= ($self->{SRU} =~ /\?/) ? '&' : '?';
    }

    bless $self, $class;
}

=head2 getPPN ( $ppn [, $prefix ] )

Get a record specified by its PPN. Returns a L<PICA::Record> object or undef.
Only available for SRU and unAPI at the moment. If both are specified, unAPI
is used.

=cut

sub getPPN {
    my ($self, $ppn, $prefix) = @_;

    croak("No SRU or unAPI interface defined") unless $self->{SRU} or $self->{unAPI};
    croak("Not a PPN: $ppn") unless $ppn =~ /^[0-9]+[0-9Xx]$/;

    my $ua = LWP::UserAgent->new( agent => 'PICA::Source/'.$PICA::Source::VERSION);

    if ( $self->{unAPI} ) { # experimental only!
        # TODO: this is not good unAPI => change unAPI server
	# TODO: unapi server does not set encoding header (utf8)
        my $id = defined $prefix ? "$prefix:ppn:$ppn" : "ppn:$ppn";
        my $url = $self->{unAPI}
                . ((index($self->{unAPI},'?') == -1) ? '?' : '&')
                . "format=pp&id=$id";
        print STDERR "URL: $url\n";
        my $request = HTTP::Request->new(GET => $url);
        my $response = $ua->request($request);
        if ($response->is_success) {
            my $data = $response->decoded_content();
            my $record = PICA::Record->new( $data );
            return $record;
        } else {
            croak("unAPI request failed: $url");
        }
    } else {
        my $query = "pica.ppn\%3D$ppn"; # CQL query

        my $url = $self->{SRU} . "query=" . $query . "&recordSchema=pica&version=1.1&operation=searchRetrieve";

        print STDERR "URL: $url\n";

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
}

=head2 cqlQuery ( $cql [, %handlers ] )

Perform a CQL query (SRU). If only one parameter is given, the full 
XML response is returned and you can parse it with L<PICA::SRUSearchParser>.

If you supply an additional hash with Record and Field handlers
(see L<PICA::Parser>) this handlers are used. Afterwards the parser
is returned.

=cut

sub cqlQuery {
    my ($self, $cql, %handlers) = @_;

    croak("No SRU interface defined") unless $self->{SRU};
    my $ua = LWP::UserAgent->new( agent => 'PICA::Source/' . $PICA::Source::VERSION);
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

=head2 z3950Query ( $query [, %handlers ] )

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

Copyright (C) 2007-2009 by Verbundzentrale Göttingen (VZG) and Jakob Voß

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.
