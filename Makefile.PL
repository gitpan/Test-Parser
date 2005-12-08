use ExtUtils::MakeMaker;
use strict;

my %opts = (
            'NAME'          => "Test::Parser",
            'AUTHOR'        => "Bryce Harrington <bryce\@osdl.org>",
            'ABSTRACT_FROM' => "lib/Test/Parser.pm",
            'VERSION'       => '0.99',
            'EXE_FILES'     => [ qw( 
                                     ) ],
            'PREREQ_PM'     => {
                'Pod::Usage'     => 0,
                'Getopt::Long'   => 0,
            },
);

WriteMakefile( %opts )

# vi:set ai ts=4 sw=4 expandtab:
