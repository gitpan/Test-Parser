=head1 NAME

Test::Parser - Base class for parsing log files from test runs, and
displays in an XML syntax.

=head1 SYNOPSIS

 use Test::Parser::MyTest;

 my $parser = new Test::Parser::MyTest;
 $parser->parse($text) 
    or die $parser->error(), "\n";
 printf("Num Errors:    %8d\n", $parser->num_errors());
 printf("Num Warnings:  %8d\n", $parser->num_warnings());

 printf("\nErrors:\n");
 foreach my $err ($parser->errors()) {
     print $err;
 }

 printf("\nWarnings:\n");
 foreach my $warn ($parser->warnings()) {
     print $warn;
 }

 print $parser->to_xml();

=head1 DESCRIPTION

This module serves as a common base class for test log parsers.  These
tools are intended to be able to parse output from a wide variety of
tests - including non-Perl tests.

The parsers also write the test data into the 'Test Result Publication
Interface' (TRPI) XML schema, developed by SpikeSource.  See
http://www.spikesource.com/testresults/index.jsp?show=trpi-schema

=head1 FUNCTIONS

=cut

package Test::Parser;

use strict;
use warnings;
use File::Basename;

use fields qw(
              name
              path
              warnings
              errors
              num_executed
              num_passed
              num_failed
              num_skipped
              );

use vars qw( %FIELDS $VERSION );
our $VERSION = '1.00';

=head2 new()

Creates a new Test::Parser object.

=cut

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = bless [\%FIELDS], $class;

    $self->{warnings}      = [];
    $self->{errors}        = [];
    $self->{num_executed}  = 0;
    $self->{num_passed}    = 0;
    $self->{num_failed}    = 0;
    $self->{num_skipped}   = 0;

    return $self;
}

sub name {
    my $self = shift;
    if (@_) {
        $self->{name} = @_;
    }
    return $self->{name};
}

sub path {
    my $self =shift;
    if (@_) {
        $self->{path} = @_;
    }
    return $self->{path};
}

sub warnings {
    my $self = shift;
    if (@_) {
        $self->{warnings} = shift;
    }
    $self->{warnings} ||= [];
    return $self->{warnings};
}

sub num_warnings {
    my $self = shift;
    return 0 + @{$self->warnings()};
}

sub errors {
    my $self = shift;
    if (@_) {
        $self->{errors} = shift;
    }
    $self->{errors} ||= [];
    return $self->{errors};
}

sub num_errors {
    my $self = shift;
    return 0 + @{$self->errors()};
}

sub num_executed {
    my $self = shift;
    return $self->{num_executed};
}

sub num_passed {
    my $self = shift;
    return $self->{num_passed};
}

sub num_failed {
    my $self = shift;
    return $self->{num_failed};
}

sub num_skipped {
    my $self = shift;
    return $self->{num_skipped};
}


=head2 parse($input, [$name[, $path]])

Call this routine to perform the parsing process.  $input can be any of
the following:

    * A text string
    * A filename of an external log file to parse
    * An open file handle (e.g. \*STDIN)

If you are dealing with a very large file, then using the filename
approach will be more memory efficient.  If you wish to use this program
in a pipe context, then the file handle style will be more suitable.

This routine simply iterates over each newline-separated line of text,
calling _parse_line.  Note that the default _parse_line() routine does
nothing particularly interesting, so you will probably wish to subclass
Test::Parser and provide your own implementation of parse_line() to do
what you need.

The 'name' argument allows you to specify the log filename or other
indication of the source of the parsed data.  'path' allows specification
of the location of this file within the test run directory.  By default,
if $input is a filename, 'name' and 'path' will be taken from that, else
they'll be left blank.

=cut

sub parse {
    my $self = shift;
    my $input = shift or return undef;
    my ($name, $path) = @_;

    my $retval = 1;
    $self->{_state} = undef;

    # If it's a GLOB, we're probably reading from STDIN
    if (ref($input) eq 'GLOB') {
        while (<$input>) {
            $retval = $self->parse_line($_) || $retval;
        }
    }
    # If it's a scalar and has newlines, it's probably the full text
    elsif (!ref($input) && $input =~ /\n/) {
        foreach (split /\n/, $input) {
            $retval = $self->parse_line($_) || $retval;
        }
    }

    # If it appears to be a valid filename, assume we're reading an external file
    elsif (!ref($input) && -f $input) {
        $name ||= basename($input);
        $path ||= dirname($input);

        open (FILE, "< $input")
            or warn "Could not open '$input' for reading:  $!\n"
            and return undef;
        while (<FILE>) {
            $retval = $self->parse_line($_) || $retval;
        }
        close(FILE);
    }
    $self->{name} = $name;
    $self->{path} = $path;

    return $retval;
}


=head2 parse_line($text)

Virtual function for parsing a line of test result data.  The base class' 
implementation of this routine does nothing interesting.

You will need to override this routine to customize it to your
application.  The parse() routine will call this iteratively for each
line of text in the test output file.

Returns undef on error.  The error message can be retrieved via error().

=cut

sub parse_line {
    my $self = shift;
    my $text = shift or return undef;

    return undef;
}


=head2 num_warnings()

The number of warnings found

=head2 warnings()

Returns a reference to an array of the warnings encountered.

=head2 num_errors()

The number of errors found

=head2 errors()

Returns a reference to an array of the errors encountered.

=head1 AUTHOR

Bryce Harrington <bryce@osdl.org>

=head1 COPYRIGHT

Copyright (C) 2005 Bryce Harrington.
All Rights Reserved.

This script is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<perl>, L<Test::Metadata>

=cut


1;
