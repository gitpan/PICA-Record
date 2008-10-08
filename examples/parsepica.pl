#!/usr/bin/perl

=head1 NAME

parsepica - parse PICA+ data and print summary information

=cut

use strict;

# include PICA packages
use PICA::Record;
use PICA::Field;
use PICA::Parser;
use PICA::Writer;
use PICA::Server;
use PICA::XMLWriter;

# include other packages
use Getopt::Long;
use Pod::Usage;

my ($outfilename, $badfilename, $logfile, $inputlistfile, $dumpformat, $verbosemode);
my ($quiet, $help, $man, $select, $selectprint, $xmlmode, $loosemode, $countmode);
my %fieldstat_a; # all
my %fieldstat_e; # exist?
my %fieldstat_r; # number of records

GetOptions(
    "output:s" => \$outfilename,   # print valid records to a file
    "bad:s" => \$badfilename,      # print invalid records to a file
    "log:s" => \$logfile,          # print messages to a file
    "files:s" => \$inputlistfile,  # read names of input files from a file
    "quiet" => \$quiet,            # suppress status messages
    "help|?" => \$help,            # show help message
    "man" => \$man,                # full documentation
    "select:s" => \$select,        # select a special field/subfield
    "pselect:s" => \$selectprint,
    "count" => \$countmode,
    "D" => \$dumpformat,
    "v" => \$verbosemode,
    #"loose" => \$loosemode,        # loose parsing
    "xml" => \$xmlmode
) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-verbose => 2) if $man;

# TODO: documentation
if (defined $selectprint) {
    $select = $selectprint;
    $quiet = 1 if (!defined $logfile and $logfile ne "-");
    $outfilename = '-' if !defined $outfilename;	
}

# Logfile
$logfile = "-" if (!$logfile && !$quiet);
if ($logfile and $logfile ne "-") {
    open LOG, ">$logfile" 
        or die("Error opening $logfile\n");
} else {
    *LOG = *STDOUT;
}

# XML mode by default if output file ends with .xml
$xmlmode = 1 if $outfilename =~ /\.xml$/;

# Output stream
my $output = $xmlmode ? PICA::XMLWriter->new() : PICA::Writer->new();

if ($outfilename) {
    $output->reset( ($outfilename ne "-") ? $outfilename : \*STDOUT );
    print LOG "Output to " . $output->name . "\n" if $output->name;
}

# init input file list if specified
if ($inputlistfile) { 
    if ($inputlistfile eq "-") {
        *INFILES = *STDIN;
    } else {
        print LOG "Reading input files from $inputlistfile\n";
        open INFILES, $inputlistfile or die("Error opening $inputlistfile");
    }
}

# handlers
my $_field_handler = \&field_handler;
my $_record_handler = \&record_handler;

# select mode
my $field_regex;
my $subfield_select;

if ($select) {
    my ($tag, $subfield) = ("","");

    if ( index($select, '$') > 3 ) {
        ($tag, $subfield) = split(/\$/,$select);
    } else {
        $tag = $select;
    }

    $field_regex = qr/^$tag$/;
    $subfield_select = $subfield if $subfield ne "";

    $_field_handler = \&select_field_handler;
    undef $_record_handler;

    print LOG "Selecting field: $select\n" if !$quiet;
}

my $remote_counter = 0;
my $remote_empty = 0;

my %options;
%options = ('Dumpformat'=>1) if $dumpformat;

# init parser
my $parser = PICA::Parser->new(
    Field => $_field_handler,
    Record => $_record_handler,
    %options
);

# parse files given at the command line, in the input file list or STDIN
my $filename;
if (@ARGV > 0) {
    if ($inputlistfile) {
        print STDERR "You can only specify either an input file or a file list!\n";
        exit 0;
    }
    while (($filename = shift @ARGV)) {
        my ($sruurl, $z3950host);
        if ($filename =~ /^http:\/\//) { # SRU (http://...)
            $sruurl = $filename;
        } elsif ($filename =~ /^[^\\:]+:\d+/) { # Z3950 (host:port[/db])
            $z3950host = $filename;
        }
        if ($sruurl or $z3950host) {
            my $query = shift @ARGV;
            if (!$query) {
                print SDTERR "query missing!\n";
            } else {
                my $remote_parser;
                if ($sruurl) {
                    print LOG "SRU query '$query' to $sruurl\n";
                    my $server = PICA::Server->new( SRU => $sruurl );
                    $remote_parser = $server->cqlQuery( $query,
                        # TODO: better pipe this to another parser (RecordParser)
                        Field => $_field_handler,
                        Record => $_record_handler
                    );
                } else {
                    print LOG "Z3950 query '$query' to $z3950host\n";
                    my $server = PICA::Server->new( Z3950 => $z3950host );
                    $remote_parser = $server->z3950Query( $query,
                        # TODO: better pipe this to another parser (RecordParser)
                        Field => $_field_handler,
                        Record => $_record_handler
                    );
                }
                $remote_counter += $remote_parser->counter();
                $remote_empty += $remote_parser->empty();
            }
        } else {
            print LOG "Reading $filename\n" if !$quiet;
            $parser->parsefile($filename);
        }
    }
} elsif ($inputlistfile) {
    while(<INFILES>) {
        chomp;
        next if $_ eq "";
        $filename = $_;
        print LOG "Reading $filename\n" if !$quiet;
        $parser->parsefile($filename);
    }
} else {
    print LOG "Reading standard input\n" if !$quiet;
    $parser->parsefile( \*STDIN ); 
}

# Finish
$output->end_document() if $xmlmode;

# Print summary
# TODO: Input fields: ...
print LOG "Input records:\t" . ($parser->counter() + $remote_counter) .
      "\nEmpty records:\t" . ($parser->empty() + $remote_empty) .
      "\nOutput records:\t" . $output->counter() .
      "\nOutput fields:\t" . $output->fields() .
      "\n" if !$quiet;

if ($countmode) {
  print "Frequency of tags in all records:\n";
  foreach my $tag (sort keys %fieldstat_a) {
      print "$tag\t" . $fieldstat_a{$tag} . "\t";
      print $fieldstat_r{$tag};
      print "\n";
  }
}


#### handler methods ####

# default field handler
sub field_handler {
    my $field = shift;

    if ($countmode) {
        my $tag = $field->tag;
        if (defined $fieldstat_a{$tag}) {
          $fieldstat_a{$tag}++;
        } else {
          $fieldstat_a{$tag} = 1;
        }
        $fieldstat_e{$tag} = 1;
    }

    return $field;
}

# flushing field handler
#sub flush_field_handler {
#    my $field = shift;
#    $output->writefield( $field );
#}

# selecting field handler
sub select_field_handler {
    # TODO: Combine with count/default handler

    my $field = shift;
    return unless $field->tag() =~ $field_regex;
    if (defined $subfield_select) {
        my @sf = $field->subfield($subfield_select);
        print join("\n",@sf) . "\n" if @sf;
    } else {
        $output->writefield($field);
    }
}

# default record handler
sub record_handler {
    my $record = shift;

    if ($countmode) {
        foreach my $tag (keys %fieldstat_e) {
            if (defined $fieldstat_r{$tag}) {
                $fieldstat_r{$tag}++;
            } else {
                $fieldstat_r{$tag} = 1;
            }
        }
        %fieldstat_e = ();
    }

    # TODO
    if ($verbosemode) {
        print LOG $parser->counter() ."\n" unless ($parser->counter() % 100);
    }

    $output->write( "Record " . $parser->counter(), $record);
}

# selecting record handler
sub select_record_handler {
    my $record = shift;

 # TODO
 #   foreach (@sf) {
 #       print "$_\n"
 #   }
}

=head1 SYNOPSIS

parsepica.pl [options] [file(s) or SRU-Server(s) and queries(s)..]

=head1 OPTIONS

 -help          brief help message
 -man           full documentation with examples
 -log FILE      print logging to a given file ('-': STDOUT, default)
 -input FILE    file with input files on each line ('-': STDIN)
 -output FILE   print all valid records to a given file ('-': STDOUT)
 -xml           output of records in XML
 -quiet         supress logging
 -select        select a specific field (no XML output possible yet)
 -pselect       select (sub)fields and print values
 -D             read dumpfile format (no newlines)

Not fully implemented yet:
 -bad FILE      print invalid records to a given file ('-': STDOUT)
 -sru SRU       fetch records via SRU. command line arguments are cql
                statements instead of files
 -z3950         fetch records via Z39.50

=head1 DESCRIPTION

This script demonstrates how to use the Perl PICA module. It can be used 
to check and count records. Input files can be specified as arguments or
from an input file list. Compressed files (C<.gz>) can directly be read.
If no input file is specified then input is read from STDIN.

Logging information is printed to STDOUT (unless quiet mode is set) or to 
a specified logfile. Read records can be written back to a given file or 
to STDOUT ('-') . Records that cannot be parseded produce error messages 
to STDERR.

Selecting fields with parsepica is around half as fast as using 
grep, but grep does not really parse and check for wellformedness.

=head1 EXAMPLES

=over 4

=item parsepica.pl picadata -o checkedrecords

Read records from 'picadata' and print parseable records to 'checkedrecords'.

=item parsepica.pl picadata -s 021A -o - -q

Select all fields '021A' from 'picadata' and write to STDOUT.

=item parsepica.pl http://gso.gbv.de/sru/DB=2.1/ pica.isb=3-423-31039-1

Get records with ISBN 3-423-31039-1 via SRU.

=back

=head1 TODO

Error handling needs to be implemented to collect broken records.

Examples to implement:

parsepica.pl -b errors picadata

Parse records in C<picadata> and print records that are not 
wellformed to C<errors>. The number of records will be reported.

parsepica.pl -out checked -bad errors -quiet picadata.gz

Parse records in C<picadata.gz>. Print records that are wellformed 
to C<checked> and the other records to C<errors>. Supress any messages. 

=head1 AUTHOR

Jakob Voss C<< jakob.voss@gbv.de >>
