package PICA::Source;

=head1 NAME

PICA::Source - Data source that can be queried for PICA+ records

=cut

use strict;
our $VERSION = "0.52";

=head1 SYNOPSIS

  my $server = PICA::Source->new(
      SRU => "http://my.server.org/sru-interface.cgi"
  );
  my $record = $server->getPPN('1234567890');
  $server->cqlQuery("pica.tit=Hamster")->count();

  # Get connection details from a config file
  $store = PICA::Source->new( config => "myconf.conf" );

  $result = $server->cqlQuery("pica.tit=Hamster", Limit => 15 );
  $result = $server->z3950Query('@attr 1=4 microformats');

  $record = $server->getPPN("1234567890");

Instead or in addition to SRU you can use Z39.50, PSI, and unAPI (experimental).

=cut

use Carp qw(croak);
use PICA::PlainParser;
use PICA::SRUSearchParser;
use PICA::Store;
use LWP::Simple;
use Unicode::Normalize qw(NFC);

=head1 METHODS

=head2 new ( [ %params ] )

Create a new Server. You can specify an SRU interface with C<SRU>, 
a Z39.50 server with C<Z3950>, an unAPI base url with C<unAPI> or a
raw PICA PSI interface with c<PSI>. Optional parameters include
C<user> and C<password> for authentification. If you provide a C<config>
parameter, configuration parameters will read from a file.

=cut

sub new {
    my ($class, %params) = @_;
    $class = ref $class || $class;

    $PICA::Store::readconfigfile->( \%params )
        if exists $params{config} or exists $params{conf} ;

    my $self = {
        SRU => $params{SRU} ? $params{SRU} : undef,
        Z3950 => $params{Z3950} ? $params{Z3950} : undef,
        unAPI => $params{unAPI} ? $params{unAPI} : undef,
        PSI => $params{PSI} ? $params{PSI} : undef,
        user => $params{user} ? $params{user} : undef,
        password => $params{password} ? $params{password} : undef,
        prev_record => undef,
    };

    if ($self->{SRU} and not $self->{SRU} =~ /[\?&]$/) {
        $self->{SRU} .= ($self->{SRU} =~ /\?/) ? '&' : '?';
    }
    if ($self->{PSI}) {
        $self->{PSI} =~ s/\/$//;
    }

    bless $self, $class;
}

=head2 getPPN ( $ppn )

Get a record specified by its PPN. Returns a L<PICA::Record> object or undef.
Only available for source APIs SRU, unAPI, and PSI. You should check whether 
the returned object is empty or not. On error the special variable $@ is set.

=cut

sub getPPN {
    my ($self, $id) = @_;

    croak("No SRU, PSI or unAPI interface defined")
        unless $self->{SRU} or $self->{unAPI} or $self->{PSI};

    if ( $self->{PSI} or $self->{unAPI} ) {
        my $url;

        if ( $self->{PSI} ) {
            $url = $self->{PSI} . "/PLAIN=ON/CHARSET=UTF8/PLAINTTLCHARSET=UTF8/URLENCODE=Y/PPN?PPN=$id";
        } else {
            my $url = $self->{unAPI}
                    . ((index($self->{unAPI},'?') == -1) ? '?' : '&')
                    . "format=pp&id=$id";
            # TODO: unapi server does not set encoding header (utf8)?
        }

        my $data = LWP::Simple::get( $url );
        if (not $data) {
            $@ = "HTTP request failed: $url";
            return;
        }

        if ( $self->{PSI} ) {
            utf8::downgrade( $data ); # make sure that the UTF-8 flag is off
            $data = url_decode($data);
            utf8::decode($data);
            $data = NFC($data); # compose combining chars  
            utf8::upgrade($data);
        }
        my $record = eval { PICA::Record->new( $data ) } ;
        if ($record) {
            return $record;
        } else {
            $@ = "Failed to parse PICA::Record";
            return;
        }
    } else {
        my $result = $self->cqlQuery( "pica.ppn=$id", Limit => 1 );
        my ($record) = $result->records();
        return $record;
    } # TODO: use z3950
}

=head2 cqlQuery ( $cql [ $parser | %params | ] )

Perform a CQL query and return the L<PICA::XMLParser> object that was used to
parse the resulting records. You can pass an existing Parser or parser 
parameters as listed at L<PICA::Parser>. Only available for API type C<SRU>.

=cut

sub cqlQuery {
    my ($self, $cql) = @_;

    croak("No SRU interface defined") unless $self->{SRU};

    my $xmlparser = UNIVERSAL::isa( $_[2], "PICA::XMLParser" ) 
                  ? $_[2] : PICA::XMLParser->new( @_ );
    my $sruparser = PICA::SRUSearchParser->new( $xmlparser );

    my $options = "";
    $cql = url_encode($cql); #url_unicode_encode($cql);
    my $baseurl = $self->{SRU} . "&recordSchema=pica&version=1.1&operation=searchRetrieve";

    my $startRecord = 1;
    while(1) {
        my $options = "&startRecord=$startRecord";
        my $url = $baseurl . "&query=" . $cql . $options;

        # print "$url\n"; # TODO: logging

        my $xml = LWP::Simple::get( $url );
        croak("SRU Request failed $url") unless $xml; # TODO: don't croak?
        $xmlparser = $sruparser->parse($xml);

        #print "numberOfRecords " . $sruparser->numberOfRecords() . "\n";
        #print "resultSetId " . $sruparser->resultSetId()  . "\n";
        #print "current counter " . $xmlparser->counter() . "\n";  

        return $xmlparser unless $sruparser->currentNumber(); # zero results
        $startRecord += $sruparser->currentNumber();
        return $xmlparser if $sruparser->numberOfRecords() < $startRecord;
        return $xmlparser if $xmlparser->finished();
    }
}

=head2 z3950Query ( $query [, $plainparser | %params ] )

Perform a Z39.50 query via L<ZOOM>. The resulting records are read with
a L<PICA::PlainParser> that is returned.

=cut

sub z3950Query {
    my ($self, $query, %handlers) = @_;

    eval { require ZOOM; require ZOOM::Options; require ZOOM::Connection; };
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

    %handlers = () unless %handlers;
    $handlers{Proceed} = 1;

    my $parser = PICA::PlainParser->new( %handlers );
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
        return $parser if $parser->finished();
    }
    return $parser;
}

=head2 baseURL

Return the base URL (if specified) or the empty string.

=cut

sub baseURL {
    my $self = shift;

    return $self->{PSI} if $self->{PSI};
    return $self->{unAPI} if $self->{unAPI};
    return $self->{SRU} if $self->{SRU};

    return "";
}

=head1 UTILITY FUNCTIONS

The following methods are based on L<CGI::Utils> by Don Owens.

=head2 url_encode

Returns the fully URL-encoded version of the given string.
It does not convert space characters to '+' characters.

=cut

sub url_encode {
    my $str = shift;
    $str =~ s{([^A-Za-z0-9_\.\*])}{sprintf("%%%02x", ord($1))}eg;
    return $str;
}

=head2 url_decode

Returns the fully URL-decoded version of the given string.

=cut

sub url_decode {
    my $str = shift;
    $str =~ tr/+/ /;
    $str =~ s|%([A-Fa-f0-9]{2})|chr(hex($1))|eg;
    return $str;
}


# Returns the fully URL-encoded version of the given string as
# unicode characters.  It does not convert space characters to 
# '+' characters.
# sub url_unicode_encode {
#    my $str = shift;
#    $str =~ s{([^A-Za-z0-9_\.\*])}{sprintf("%%u%04x", ord($1))}eg;
#    return $str;
#}

1;

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007-2009 by Verbundzentrale Goettingen (VZG) and Jakob Voss

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.
