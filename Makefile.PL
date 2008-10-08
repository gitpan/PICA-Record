use 5.005;
use strict;
use ExtUtils::MakeMaker;

&WriteMakefile(
    NAME            => 'PICA::Record',
    DISTNAME        => 'PICA-Record',
    VERSION_FROM    => 'lib/PICA/Record.pm',
    ABSTRACT_FROM   => 'lib/PICA/Record.pm',
    PMLIBDIRS       => [ qw( lib/ ) ],
    AUTHOR          => 'Jakob Voss <jakob.voss@gbv.de>',
    PREREQ_PM       => {
        'Carp' => 0,
        'XML::Parser' => 0,
        'LWP::UserAgent' => 0,
        'SOAP::Lite' => 0
    },
    dist            => {
        COMPRESS => 'gzip -9f',
        SUFFIX => 'gz',
    },
    depend          => {
        Makefile => '$(VERSION_FROM)'
    },
    clean           => { FILES => 'PICA-Record-*' },
);
