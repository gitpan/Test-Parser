package Test::Parser::SysbenchCPU;

=head1 NAME

Test::Parser::SysbenchCPU - Perl module to parse output from Sysbench --test=cpu

=head1 SYNOPSIS

    use Test::Parser::SysbenchCPU;
    my $parser = new Test::Parser::SysbenchCPU;
    $parser->parse($text)

    printf("     Threads:  %15s\n", $parser->summary('threads'));
    printf("   Max Prime:  %15s\n", $parser->summary('maxprime'));
    printf("  Total Time:  %15s\n", $parser->totals('time'));
    printf("Total Events:  %15s\n", $parser->totals('events'));
    printf("  Total Exec:  %15s\n", $parser->totals('exec'));
    printf("      PR Min:  %15s\n", $parser->per_request('min'));
    printf("      PR Avg:  %15s\n", $parser->per_request('avg'));
    printf("      PR Max:  %15s\n", $parser->per_request('max'));
    printf("95th Percent:  %15s\n", $parser->per_request('95'));
    printf("   Event Avg:  %15s\n", $parser->eventfair('avg'));
    printf("Event StdDev:  %15s\n", $parser->eventfair('stddev'));
    printf("    Exec Avg:  %15s\n", $parser->execfair('avg'));
    printf(" Exec StdDev:  %15s\n", $parser->execfair('stddev'));

Additional information is available from the subroutines listed below
and from the L<Test::Parser> baseclass.

=head1 DESCRIPTION

This module provides a way to parse and neatly display information gained from the 
Sysbench CPU test.  This module will parse the output given by this command and
command similar to it:  `sysbench --test=cpu > cpu.output`  The cpu.output contains
the necessary information that SysbenchCPU is able to parse.

=head1 FUNCTIONS

See L<Test::Parser> for functions available from the base class.

=cut

use strict;
use warnings;
use Test::Parser;

@Test::Parser::SysbenchCPU::ISA = qw(Test::Parser);
use base 'Test::Parser';

use fields qw(
              data
              );

use vars qw( %FIELDS $AUTOLOAD $VERSION );
our $VERSION = '1.4';


=head2 new()

	Purpose: Create a new Test::Parser::SysbenchCPU instance
	Input: None
	Output: SysbenchCPU object

=cut
sub new {
    my $class = shift;
    my Test::Parser::SysbenchCPU $self = fields::new($class);
    $self->SUPER::new();

    $self->testname('sysbench');
    $self->description('A variety of tests');
    $self->summary('Lots of things');
    $self->license('');
    $self->vendor('');
    $self->release('');
    $self->url('');
    $self->platform('');
#    $self->type('unit');

    $self->{data} = ();

    return $self;
}


=head2 data()

	Purpose: Return a hash representation of the Sysbench data
	Input: None
	Output: SysbenchCPU data

=cut
sub data {
    my $self = shift;
    if (@_) {
        $self->{data} = @_;
    }
    return {sysbench => {data => $self->{data}}};
}


=head2 parse_line()

	Purpose: Parse Sysbench --test=cpu log files.  This method override's the default parse_line() of Test::Parser
	Input: String (one line of log file)
	Output: 1

=cut
sub parse_line {
    my $self = shift;
    my $line = shift;

    my $label1 = '';
    my $temp1 = '';

    my $label2 = '';
    my $temp2 = '';

    # Trim any leading and trailing whitespaces.
    $line =~ s/(^\s+|\s+$)//g;

    # Determine what info we have in the line...
    if ($line =~ /^Number .*?threads:(.+)/) {
        $temp1 = $1;
        $label1 = 'sum_threads';
    }

    elsif ($line =~ /^sysbench v(.+):/) {
        $self->version($1);
    }

    elsif ($line =~ /^Maximum .*?test:(.+)/) {
        $temp1 = $1;
        $label1 = 'sum_maxprime';
    }

    elsif ($line =~ /^total .*?ime:(.+)/) {
        $temp1 = $1;
        $label1 = 'total_time';
    }

    elsif ($line =~ /^total .*?events:(.+)/) {
        $temp1 = $1;
        $label1 = 'total_events';
    }

    elsif ($line =~ /^total .*?execution:(.+)/) {
        $temp1 = $1;
        $label1 = 'total_exec';
    }

    elsif ($line =~ /^min:(.+)/) {
        $temp1 = $1;
        $label1 = 'pr_min';
    }

    elsif ($line =~ /^avg:(.+)/) {
        $temp1 = $1;
        $label1 = 'pr_avg';
    }

    elsif ($line =~ /^max:(.+)/) {
        $temp1 = $1;
        $label1 = 'pr_max';
    }

    elsif ($line =~ /^approx. .*?tile:(.+)/) {
        $temp1 = $1;
        $label1 = 'pr_95';
    }

    # These are done together as there are 2 pieces of information on each line
    elsif ($line =~ /^events .*?:(.+)\/(.+)/) {
        $temp1 = $1;
        $temp2 = $2;
        $label1 = 'event_avg';
        $label2 = 'event_stddev';
    }

    # These are done together as there are 2 pieces of information on each line
    elsif ($line =~ /^execution .*?:(.+)\/(.+)/) {
        $temp1 = $1;
        $temp2 = $2;
        $label1 = 'exec_avg';
        $label2 = 'exec_stddev';
    }

    # Kill any leading or trailing spaces for neatness

   
    if($temp1 ne '') {
        $temp1 =~ s/(^\s+|\s+$)//g;    
        my $col = $self->add_column($label1);
        $self->add_data($temp1, $col);
#        if( !defined($self->{$label1}) ) {
#            $self->{$label1} = {};
#        }
#        $self->{$label1} = $temp1;
    }

    if($temp2 ne '') {
        $temp2 =~ s/(^\s+|\s+$)//g;
        my $col = $self->add_column($label2);
        $self->add_data($temp2, $col);
#        if( !defined($self->{$label2}) ) {
#            $self->{$label2} = {};
#        }
#        $self->{$label2} = $temp2;
    }

    return 1;
}


=head2 summary()

	Purpose: Return Summary information for the Sysbench test
	Input: 'threads' or 'maxprime'
	Output: The number of threads OR the prime number calculated OR undef

=cut
sub get_summary {
    my $self = shift;
    my $input = shift || return undef;
    return $self->{"sum_$input"};
}


=head2 totals()

	Purpose: Return Totals information for the Sysbench test
	Input: 'time' or 'events' or 'exec'
	Output: The total time of execution OR the total number of events OR the total time taken by execution of all events OR undef

=cut
sub totals {
    my $self = shift;
    my $input = shift || return undef;
    return $self->{"total_$input"};
}


=head2 per_request()

	Purpose: Return Per-Request information for the Sysbench test
	Input: 'min' or 'avg' or 'max' or 95'
	Output: The minimum OR average OR maximum amount of time per request OR the 9th percentile of time per request OR undef

=cut
sub per_request {
    my $self = shift;
    my $input = shift || return undef;
    return $self->{"pr_$input"};
}


=head2 eventfair()

	Purpose: Return the Thread Fairness information for the Sysbench test
	Input: 'avg' OR 'stddev'
	Output: The average OR standard deviation of thread event fairness OR undef

=cut
sub eventfair {
    my $self = shift;
    my $input = shift || return undef;
    return $self->{"event_$input"};
}


=head2 execfair()

	Purpose: Return the Thread Fairness information for the Sysbench test
	Input: 'avg' OR 'stddev'
	Output: The average OR standard deviation of thread execution fairness OR undef

=cut
sub execfair {
    my $self = shift;
    my $input = shift || return undef;
    return $self->{"exec_$input"};
}

1;
__END__

=head1 AUTHOR

John Daiker <jdaiker@osdl.org>

=head1 COPYRIGHT

Copyright (C) 2006 John Daiker & Open Source Development Labs, Inc.
All Rights Reserved.

This script is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Test::Parser>

=end
