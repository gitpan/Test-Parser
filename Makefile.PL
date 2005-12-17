use ExtUtils::MakeMaker;
use strict;

my %opts = (
            'NAME'          => "Test::Parser",
            'AUTHOR'        => "Bryce Harrington <bryce\@osdl.org>",
            'ABSTRACT_FROM' => "lib/Test/Parser.pm",
            'VERSION'       => '1.00',
            'EXE_FILES'     => [ qw( 
                                     scripts/kernel2trpi
                                     scripts/parse_build_kernel
                                     ) ],
            'PREREQ_PM'     => {
                'Pod::Usage'     => 0,
                'Getopt::Long'   => 0,
            },
);

WriteMakefile( %opts )

# vi:set ai ts=4 sw=4 expandtab:
