#!/usr/bin/perl

=head1 NAME

picadata - parse PICA+ data and print summary information

=cut

# include PICA packages
use PICA::Record;
use PICA::Field;
use PICA::Parser;
use PICA::Writer;
use PICA::XMLWriter;

# include other packages
use Getopt::Long;
use Pod::Usage;

my ($outfilename, $badfilename, $logfile, $inputlistfile);
my ($quiet, $help, $man, $select, $selectprint, $xmlmode, $loosemode);

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
        print LOG "Reading input files from $inputfilelist\n";
        open INFILES, $inputfilelist or die("Error opening $inputfilelist");
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

# init parser
my $parser = PICA::Parser->new(
    Field => $_field_handler,
    Record => $_record_handler,
);

# parse files given at the command line, in the input file list or STDIN
if (@ARGV > 0) {
    if ($inputfilelist) {
    	print STDERR "You can only specify either an input file or a file list!\n";
    	exit 0;
    }
    foreach my $filename (@ARGV) {
        print LOG "Reading $filename\n" if !$quiet;
        $parser->parsefile($filename);
    }
} elsif ($inputfilelist) {
    while(<INFILES>) {
        chomp;
        next if $_ eq "";
        my $filename = $_;
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
print LOG "Input records:\t" . $parser->counter() .
      "\nEmpty records:\t" . $parser->empty_counter() .
      "\nOutput records:\t" . $output->counter() .
      "\nOutput fields:\t" . $output->fields() .
      "\n" if !$quiet;


#### handler methods ####

# default field handler
sub field_handler {
    my $field = shift;
    return $field;
}

# flushing field handler
#sub flush_field_handler {
#    my $field = shift;
#    $output->writefield( $field );
#}

# selecting field handler
sub select_field_handler {
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

parsepica.pl [options] [files...]

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

Not fully implemented yet:
 -bad FILE      print invalid records to a given file ('-': STDOUT)

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
