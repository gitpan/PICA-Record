package PICA::Tutorial;
use strict;

use vars qw($VERSION);
$VERSION = "0.31";

1;

=head1 NAME

PICA::Tutorial - A documentation-only module for PICA::Record usage

=head1 SYNOPSIS

 perldoc PICA::Tutorial

=head1 INTRODUCTION

=head2 What is PICA?

PICA+ is the internal data format of the Local Library System (LBS) and
the Central Library System (CBS) of OCLC PICA. Similar library formats 
are the MAchine Readable Cataloging format (MARC) and the Maschinelles 
Austauschformat für Bibliotheken (MAB). In additionally to PICA+ there 
is the catalouging format Pica3 which can losslessly be convert to PICA+ 
and vice versa.

OCLC PICA is an European library cooperative which originated from a 
cooperation of the Dutch Pica foundation (Stichting Pica) and the 
Online Computer Library Center (OCLC).

=head2 What is PICA::Record?

C<PICA::Record> is a Perl package that provides an API for PICA+ record 
handling. The package contains a parser interface module L<PICA::Parser>
to parse PICA+ (L<PICA::PlainParser>) and PICA XML (L<PICA::XMLParser>).
Corresponding modules exist to write data (L<PICA::Writer> and 
L<PICA::XMLWriter>). PICA+ data is handled in records (L<PICA::Record>) 
that contain fields (L<PICA::Field>). There is also the experimental 
interface L<PICA::Server> to fetch records from databases via SRU and 
parse them afterwards with L<PICA::SRUSearchParser>.

Here are some use cases of C<PICA::Record>:

=over

=item Convert from PICA+ to PicaXML and vice versa

=item Process PICA+ records that you have downloaded with WinIBW

=item Download records from an PICA OPAC in its native PICA+ format via SRU

=back

To get an insight to the API have a look at the examples and tests 
included in this package. This document will be expanded to a full 
Tutorial for users of L<PICA::Record>. Feedback is very welcome!

The examples in the C<bin> directory include:

=over

=item dedup.pl - remove duplicate records

=item parsepica.pl - parse PICA+ records

=back

=head1 SEE ALSO

At CPAN there are the modules L<MARC::Record>, L<MARC>, and L<MARC::XML> 
for MARC records. The deprecated module L<Net::Z3950::Record> had a 
subclass L<Net::Z3950::Record::MAB> for MAB records (you should now 
use L<Net::Z3950::ZOOM>).

=head1 TODO

Full Unicode support needs more testing and probably some bugfixes.
The PICA XML format is not standardized yet so it may change in the
future. The SRU interface to fetch PICA+ records is very experimental.

=head1 AUTHOR

Jakob Voss C<< <jakob.voss@gbv.de> >>

=head1 LICENSE

Copyright (C) 2007 by Verbundzentrale Goettingen (VZG) and Jakob Voss

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version 5.8.8 or, at
your option, any later version of Perl 5 you may have available.

