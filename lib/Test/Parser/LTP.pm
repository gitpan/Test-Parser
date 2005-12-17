package Test::Parser::LTP;

my $i=0;

=head1 NAME

Test::Parser::LTP - Perl module to parse output from runs of the 
Linux Test Project (LTP) testsuite.

=head1 SYNOPSIS

 use Test::Parser::LTP;

 my $parser = new Test::Parser::LTP;
 $parser->parse($text);
 printf("Num Executed:  %8d\n", $parser->num_executed());
 printf("Num Passed:    %8d\n", $parser->num_passed());
 printf("Num Failed:    %8d\n", $parser->num_failed());
 printf("Num Skipped:   %8d\n", $parser->num_skipped());

Additional information is available from the subroutines listed below
and from the L<Test::Parser> baseclass.

=head1 DESCRIPTION

This module provides a way to extract information out of LTP test run
output.

=head1 FUNCTIONS

Also see L<Test::Parser> for functions available from the base class.

=cut

use strict;
use warnings;
use Test::Parser;

@Test::Parser::LTP::ISA = qw(Test::Parser);
use base 'Test::Parser';

use fields qw(
              _state
              _current_test
              );

use vars qw( %FIELDS $AUTOLOAD $VERSION );
our $VERSION = '1.00';

=head2 new()

Creates a new Test::Parser::LTP instance.
Also calls the Test::Parser base class' new() routine.
Takes no arguments.

=cut

sub new {
    my $class = shift;
    my Test::Parser::LTP $self = fields::new($class);
    $self->SUPER::new();

    $self->name('LTP');
    $self->type('standards');

    $self->{_state}        = undef;
    $self->{_current_test} = undef;

    return $self;
}

=head3

Override of Test::Parser's default parse_line() routine to make it able
to parse LTP output.

=cut
sub parse_line {
    my $self = shift;
    my $line = shift;

    $self->{_state} ||= 'intro';

    # Change state, if appropriate
    if ($line =~ m|^<<<(\w+)>>>$|) {
        $self->{_state} = $1;
        if ($self->{_state} eq 'test_start') {
            $self->{_current_test} = undef;
        }
        return 1;
    }

    # Parse content as appropriate to the section we're in
    if ($self->{_state} eq 'intro') {
        # TODO:  Parse the intro stuff about the system
        #        Ignoring it for now until someone needs it...

    } elsif ($self->{_state} eq 'test_start') {
        if ($line =~ m|^([\w-]+)=(.*)$|) {
            my ($key, $value) = ($1, $2);

            if ($key eq 'tag') {
                # Add the test to our collection and parse any additional
                # parameters (such as stime)
                if ($value =~ m|^([\w-]+)\s+(\w+)=(.*)$|) {
                    $self->{_current_test}->{tag} = $1;
                    ($key, $value) = ($2, $3);

                    push @{$self->{testcases}}, $self->{_current_test};
                }
            }

            $self->{_current_test}->{$key} = $value;
        }

    } elsif ($self->{_state} eq 'test_output') {
        # For lines of the form:
        # arp01       1  BROK  :  Test broke: command arp not found
        if ($line =~ m|^(\w+)\s+(\d+)\s+([A-Z]+)\s*:\s*(.*)$|) {
            my ($tag, $num, $status, $message) = ($1, $2, $3, $4);
            push @{$self->{_current_test}->{results}}, {
                tag => $tag,
                num => $num,
                status => $status,
                message => $message
                };

            if ($num == 1) {
                if ($status eq 'PASS') {
                    $self->{num_passed}++;
                } elsif ($status eq 'FAIL') {
                    $self->{num_failed}++;
                } elsif ($status eq 'BROK') {
                    $self->{num_skipped}++;
                }
            }
        }

    } elsif ($self->{_state} eq 'execution_status') {
        my @items = split /\s+/, $line;
        foreach my $item (@items) {
            if ($item =~ m|^(\w+)=(.*)$|) {
                $self->{_current_test}->{execution_status}->{$1} = $2;
            }
        }

    } elsif ($self->{_state} eq 'test_end') {
        # We've hit the end of the test record; clear buffer
        $self->{_current_test} = undef;

    } else {
        # TODO:  Unknown text...  skip it
    }

    return 1;
}

1;
__END__

=head1 AUTHOR

Bryce Harrington <bryce@osdl.org>

=head1 COPYRIGHT

Copyright (C) 2005 Bryce Harrington.
All Rights Reserved.

This script is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Test::Parser>

=end

