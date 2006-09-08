package Test::Parser::SysbenchFileIO;

=head1 NAME

Test::Parser::SysbenchFileIO - Perl module to parse output from Sysbench --test=fileio

=head1 SYNOPSIS

    use Test::Parser::SysbenchFileIO;
    my $parser = new Test::Parser::SysbenchFileIO;
    $parser->parse($text)

    printf(" Num of Threads:  %15s\n", $parser->print('num_threads'));
    printf("File Open Flags:  %15s\n", $parser->print('file_open_flags'));
    printf("Number of Files:  %15s\n", $parser->print('num_files'));
    printf("      File Size:  %15s\n", $parser->print('file_size'));
    printf("Total File Size:  %15s\n", $parser->print('total_file_size'));
    printf("     Block Size:  %15s\n", $parser->print('block_size'));
    printf(" Num Random Req:  %15s\n", $parser->print('num_random_req'));
    printf("      R/W Ratio:  %15s\n", $parser->print('rw_ratio'));
    printf("   FSYNC Status:  %15s\n", $parser->fsync('status'));
    printf("     FSYNC Freq:  %15s\n", $parser->fsync('freq'));
    printf("      FSYNC End:  %15s\n", $parser->fsync('end'));
    printf("        IO Mode:  %15s\n", $parser->print('io_mode'));
    printf("     Which Test:  %15s\n", $parser->print('test_run'));
    printf("      Perf Read:  %15s\n", $parser->ops('reads'));
    printf("     Perf Write:  %15s\n", $parser->ops('writes'));
    printf("     Perf Other:  %15s\n", $parser->ops('other'));
    printf("     Perf Total:  %15s\n", $parser->ops('total'));
    printf("      Size Read:  %15s\n", $parser->ops('read'));
    printf("   Size Written:  %15s\n", $parser->ops('written'));
    printf("    Total trans:  %15s\n", $parser->ops('trans_total'));
    printf("     Trans Rate:  %15s\n", $parser->ops('trans_rate'));
    printf("   Request Exec:  %15s\n", $parser->ops('req_rate'));
    printf("     Total Time:  %15s\n", $parser->totals('time'));
    printf("   Total Events:  %15s\n", $parser->totals('events'));
    printf("     Total Exec:  %15s\n", $parser->totals('exec'));
    printf("         PR Min:  %15s\n", $parser->per_request('min'));
    printf("         PR Avg:  %15s\n", $parser->per_request('avg'));
    printf("         PR Max:  %15s\n", $parser->per_request('max'));
    printf("   95th Percent:  %15s\n", $parser->per_request('95'));
    printf("      Event Avg:  %15s\n", $parser->eventfair('avg'));
    printf("   Event StdDev:  %15s\n", $parser->eventfair('stddev'));
    printf("       Exec Avg:  %15s\n", $parser->execfair('avg'));
    printf("    Exec StdDev:  %15s\n", $parser->execfair('stddev'));


Additional information is available from the subroutines listed below
and from the L<Test::Parser> baseclass.

=head1 DESCRIPTION

This module provides a way to parse and neatly display information gained from the 
Sysbench FileIO test.  This module will parse the output given by this command and
commands similar to it:  `sysbench --test=fileio > fileio.output`  The fileio.output contains
the necessary information that SysbenchFileIO is able to parse.

=head1 FUNCTIONS

Also see L<Test::Parser> for functions available from the base class.

=cut

use strict;
use warnings;
use Test::Parser;

@Test::Parser::SysbenchFileIO::ISA = qw(Test::Parser);
use base 'Test::Parser';

use fields qw(
              data
              );

use vars qw( %FIELDS $AUTOLOAD $VERSION );
our $VERSION = '1.4';


=head2 new()

	Purpose: Create a new Test::Parser::SysbenchFileIO instance
	Input: None
	Output: SysbenchFileIO object

=cut
sub new {
    my $class = shift;
    my Test::Parser::SysbenchFileIO $self = fields::new($class);
    $self->SUPER::new();

    $self->name('sysbench');
    $self->type('unit');

    $self->{data} = ();

    $self->{data}->{'product'} = "FIXME";
    $self->{data}->{'version'} = "FIXME";
    $self->{data}->{'desc'} = "FIXME";
    $self->{data}->{'summary'} = "FIXME";
    $self->{data}->{'license'} = "FIXME";
    $self->{data}->{'vendor'} = "FIXME";
    $self->{data}->{'release'} = "FIXME";
    $self->{data}->{'url'} = "FIXME";
    $self->{data}->{'root'} = "FIXME";
    $self->{data}->{'platform'} = "FIXME";
    $self->{data}->{'log_name'} = "FIXME";
    $self->{data}->{'log_path'} = "FIXME";
    $self->{data}->{'execed'} = "FIXME";
    $self->{data}->{'passed'} = "FIXME";
    $self->{data}->{'failed'} = "FIXME";
    $self->{data}->{'skipped'} = "FIXME";
    $self->{data}->{'expected_exec'} = "FIXME";
    $self->{data}->{'expected_pass'} = "FIXME";
    $self->{data}->{'expected_fail'} = "FIXME";
    $self->{data}->{'expected_skip'} = "FIXME";
    $self->{data}->{'coverage_percent'} = "FIXME";
    $self->{data}->{'coverage_path'} = "FIXME";
    $self->{data}->{'ccr_path'} = "FIXME";

    return $self;
}


=head2 data()

	Purpose: Return a hash representation of the Sysbench data
	Input: None
	Output: SysbenchFileIO data

=cut
sub data {
    my $self = shift;
    if (@_) {
        $self->{data} = @_;
    }
    return {sysbench => {data => $self->{data}}};
}


=head2 parse_line()

	Purpose: Parse Sysbench --test=fileio log files.  This method override's the default parse_line() of Test::Parser
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
    my $label3 = '';
    my $temp3 = '';
    my $label4 = '';
    my $temp4 = '';
    my $label5 = '';
    my $temp5 = '';
    my $label6 = '';
    my $temp6 = '';
    my $label7 = '';
    my $temp7 = '';
    my $label8 = '';
    my $temp8 = '';

    #
    # Trim any leading and trailing whitespaces.
    #
    $line =~ s/(^\s+|\s+$)//g;

    # Determine what info we have in the line...
    if ($line =~ /^Number .*?threads:(.+)/) {
        $temp1 = $1;
        $label1 = 'num_threads';
    }

    elsif ($line =~ /^Doing c(.+)/) {
        $temp1 = $1;
        $label1 = 'desc';
    }

    elsif ($line =~ /^sysbench .*v(.+):/) {
        $temp1 = "sysbench";
        $label1 = 'product';
        $temp2 = $1;
        $label2 = 'version';
    }

    elsif ($line =~ /^Extra .*?flags:(.+)/) {
        $temp1 = $1;
        $label1 = 'file_open_flags';
    }

    # These are done together as there are 2 pieces of information on each line
    elsif ($line =~ /^(.+).*?files, (\d+)(\w+).*?each/) {
        $temp1 = $1;
        $label1 = 'num_files';
        $temp2 = $2;
        $label2 = 'file_size';
        $temp3 = $3;
        $label3 = 'file_size_units';
    }

    elsif ($line =~ /^(\d+)(\w+).*?total file size/) {
        $temp1 = $1;
        $label1 = 'total_file_size';
        $temp2 = $2;
        $label2 = 'total_file_size_units';
    }

    elsif ($line =~ /^Block size (\d+)(\w+).*/) {
        $temp1 = $1;
        $label1 = 'block_size';
        $temp2 = $2;
        $label2 = 'block_size_units';
    }

    elsif ($line =~ /^Number .*?IO:(.+)/) {
        $temp1 = $1;
        $label1 = 'num_random_req';
    }

    elsif ($line =~ /^Read.*?test:(.+)/) {
        $temp1 = $1;
        $label1 = 'rw_ratio';
    }

    # These are done together as there are 2 pieces of information on each line
    elsif ($line =~ /^Periodic FSYNC(.+), calling fsync\(\) each (.+) requests/) {
        $temp1 = $1;
        $label1 = 'fsync_status';
        $temp2 = $2;
        $label2 = 'fsync_freq';
    }

    elsif ($line =~ /^Calling .*?test,(.+)./) {
        $temp1 = $1;
        $label1 = 'fsync_end';
    }

    elsif ($line =~ /^Using (.+) mode/) {
        $temp1 = $1;
        $label1 = 'io_mode';
    }

    elsif ($line =~ /^Doing (.+) test/) {
        $temp1 = $1;
        $label1 = 'test_run';
    }

    elsif ($line =~ /(.+).*Requests/) {
        $temp1 = $1;
        $label1 = 'op_req_rate';
    }

    elsif ($line =~ /^total .*?time:\s+([\.\d]+)(\w+)/) {
        $temp1 = $1;
        $temp2 = $2;
        $label1 = 'total_time';
        $label2 = 'total_time_units';
    }

    elsif ($line =~ /^total .*?events:\s+(.+)/) {
        $temp1 = $1;
        $label1 = 'total_events';
    }

    elsif ($line =~ /^total .*?execution:\s+(.+)/) {
        $temp1 = $1;
        $label1 = 'total_exec';
    }

    elsif ($line =~ /^min:\s+([\.\d]+)(\w+)/) {
        $temp1 = $1;
        $temp2 = $2;
        $label1 = 'pr_min';
        $label2 = 'pr_min_units';
    }

    elsif ($line =~ /^avg:\s+([\.\d]+)(\w+)/) {
        $temp1 = $1;
        $temp2 = $2;
        $label1 = 'pr_avg';
        $label2 = 'pr_avg_units';
    }

    elsif ($line =~ /^max:\s+([\.\d]+)(\w+)/) {
        $temp1 = $1;
        $temp2 = $2;
        $label1 = 'pr_max';
        $label2 = 'pr_max_units';
    }

    elsif ($line =~ /^approx. .*?tile:\s+([\.\d]+)(\w+)/) {
        $temp1 = $1;
        $temp2 = $2;
        $label1 = 'pr_95';
        $label2 = 'pr_95_units';
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

    # These are done together as there are 4 pieces of information on each line
    elsif ($line =~ /^Operations performed: (.+) Read, (.+) Write, (.+) Other = (.+) Total/) {
        $temp1 = $1;
        $temp2 = $2;
        $temp3 = $3;
        $temp4 = $4;
        $label1 = 'op_reads';
        $label2 = 'op_writes';
        $label3 = 'op_other';
        $label4 = 'op_total';
    }

    # These are done together as there are 4 pieces of information on each line
    elsif ($line =~ /^Read ([\.\d]+)(\w+)\s+Written\s+([\.\d]+)(\w+).*\s+transferred\s+([\.\d]+)(\w+)\s+\(([\.\d]+)(\w+)/) {
        $temp1 = $1;
        $temp2 = $2;
        $temp3 = $3;
        $temp4 = $4;
        $temp5 = $5;
        $temp6 = $6;
        $temp7 = $7;
        $temp8 = $8;
        $label1 = 'op_read';
        $label2 = 'op_read_units';
        $label3 = 'op_written';
        $label4 = 'op_written_units';
        $label5 = 'op_trans_total';
        $label6 = 'op_trans_total_units';
        $label7 = 'op_trans_rate';
        $label8 = 'op_trans_rate_units';
    }

    # Kill any leading or trailing spaces for neatness
    $temp1 =~ s/(^\s+|\s+$)//g;
    $self->{data}{$label1} = $temp1;

    if($temp2 ne '') {
        $temp2 =~ s/(^\s+|\s+$)//g;
        $self->{data}{$label2} = $temp2;
    }
    if($temp3 ne '') {
        $temp3 =~ s/(^\s+|\s+$)//g;
        $self->{data}{$label3} = $temp3;
    }
    if($temp4 ne '') {
        $temp4 =~ s/(^\s+|\s+$)//g;
        $self->{data}{$label4} = $temp4;
    }
    if($temp5 ne '') {
        $temp5 =~ s/(^\s+|\s+$)//g;
        $self->{data}{$label5} = $temp5;
    }
    if($temp6 ne '') {
        $temp6 =~ s/(^\s+|\s+$)//g;
        $self->{data}{$label6} = $temp6;
    }
    if($temp7 ne '') {
        $temp7 =~ s/(^\s+|\s+$)//g;
        $self->{data}{$label7} = $temp7;
    }
    if($temp8 ne '') {
        $temp8 =~ s/(^\s+|\s+$)//g;
        $self->{data}{$label8} = $temp8;
    }

    return 1;
}


=head2 print()

	Purpose: Print certain stats about the test
	Input: 'num_threads', 'file_open_flags', 'num_files', 'file_size', 'file_size_units', 'total_file_size', 'total_file_size_units', 'block_size', 'block_size_units', 'num_random_req', 'rw_ratio', 'io_mode', 'test_run'
	Output: String

=cut
sub print {
    my $self = shift;
    my $input = shift || return undef;
    return $self->{data}->{"$input"};
}


=head2 summary()

	Purpose: Return Summary information for the Sysbench test
	Input: 'threads', 'maxprime'
	Output: The number of threads OR the prime number calculated OR undef

=cut
sub summary {
    my $self = shift;
    my $input = shift || return undef;
    return $self->{data}->{"sum_$input"};
}


=head2 totals()

	Purpose: Return Totals information for the Sysbench test
	Input: 'time', 'time_units', 'events', 'exec'
	Output: String

=cut
sub totals {
    my $self = shift;
    my $input = shift || return undef;
    return $self->{data}->{"total_$input"};
}


=head2 per_request()

	Purpose: Return Per-Request information for the Sysbench test
	Input: 'min', 'min_units', 'avg', 'avg_units', 'max', 'max_units', '95', '95_units'
	Output: String

=cut
sub per_request {
    my $self = shift;
    my $input = shift || return undef;
    return $self->{data}->{"pr_$input"};
}

=head2 eventfair()

	Purpose: Return the Thread Fairness information for the Sysbench test
	Input: 'avg', 'stddev'
	Output: String

=cut
sub eventfair {
    my $self = shift;
    my $input = shift || return undef;
    return $self->{data}->{"event_$input"};
}


=head2 execfair()

	Purpose: Return the Thread Fairness information for the Sysbench test
	Input: 'avg', 'stddev'
	Output: String

=cut
sub execfair {
    my $self = shift;
    my $input = shift || return undef;
    return $self->{data}->{"exec_$input"};
}


=head2 fsync()

	Purpose: Returns whether or not fsync was enabled, and what options were specified if it was enabled
	Input: 'status', 'freq', 'end'
	Output: String

=cut
sub fsync {
    my $self = shift;
    my $input = shift || return undef;
    return $self->{data}->{"fsync_$input"};
}


=head2 ops()

	Purpose: Return info about the operations that were performed for the test.
	Input: 'reads', 'writes', 'other', 'total', 'read', 'read_units', 'written', 'written_units', 'trans_total', 'trans_total_units', 'trans_rate', 'trans_rate_units', 'req_rate'
	Output: String

=cut
sub ops {
    my $self = shift;
    my $input = shift || return undef;
    return $self->{data}->{"op_$input"};
}

=head2 to_xml()

	Purpose: Export the SysbenchFileIO test results in TRPI Extended format
	Input: NA
	Output: XML File

=cut
sub to_xml {

    my $self = shift;

    my $xml = "";

    $xml .= qq|<component name="$self->{data}->{'product'}" version="$self->{data}->{'version'}" xmlns="http://www.spikesource.com/xsd/2005/04/TRPI">
    <description>
      $self->{data}->{'desc'}
    </description>
    <summary>$self->{data}->{'summary'}</summary>
    <license>$self->{data}->{'license'}</license>
    <vendor>$self->{data}->{'vendor'}</vendor>
    <release>$self->{data}->{'release'}</release>
    <url>$self->{data}->{'url'}</url>
    <root>$self->{data}->{'root'}</root>

    <platform>$self->{data}->{'platform'}</platform>
|;

    $xml .= qq|
    <test log-filename="$self->{data}->{'log_name'}" path="$self->{data}->{'log_path'}">
        <data>
            <columns>
|;
    my $count = 0;
    my $unit_temp = "";
    for my $j (sort keys %{$self->{data}}) {
            if ( substr( "$j", length($j)-6, 6 ) eq "_units" ) {
            }
            else {
                if ( "$j" ne "" and "$self->{data}->{$j}" ne "FIXME" ) {
#                if ( "$self->{data}->{$j}" eq "FIXME" ) {
#                }
#                else {
                    if ( ! defined($self->{data}->{"$j" . "_units"})) {
                        $xml .= qq|                <c id="$count" name="$j"/>
|;
                    }
                    else {
                        $xml .= qq|                <c id="$count" name="$j" units="$self->{data}->{"$j" . "_units"}"/>
|;
                    }
                    $count++;
#                }
                }
            }
    }

    $xml .= qq|            </columns>
|;

    my $d_count = 1;
    $count = 0;
     for($d_count=1; $d_count <= 1; $d_count++) {
        $xml .= qq|            <datum id="$d_count">
|;
        for my $x ( sort keys%{ $self->{data} } ) {
            if ( substr( "$x", length($x)-6, 6 ) eq "_units" or "$self->{data}->{$x}" eq "FIXME" or "$x" eq "" ) {
            }
            else {
                $xml .= qq|                <d id="$count">$self->{data}->{$x}</d>
|;
                $count++;
            }
        }

        $xml .= qq|            </datum>
|;
    }

    $xml .= qq|        </data>
|;

    $xml .= qq|        <result executed="$self->{data}->{'execed'}" passed="$self->{data}->{'passed'}" failed="$self->{data}->{'failed'}" skipped="$self->{data}->{'skipped'}"/>
        <expected-result executed="$self->{data}->{'expected_exec'}" passed="$self->{data}->{'expected_pass'}" failed="$self->{data}->{'expected_fail'}" skipped="$self->{data}->{'expected_skip'}"/>
|;

    $xml .= qq|    </test>
    <coverage-report percentage="$self->{data}->{'coverage_percent'}" path="$self->{data}->{'coverage_path'}"/>
    <code-convention-report path="$self->{data}->{'ccr_path'}"/>
</component>
|;
    return $xml;
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
