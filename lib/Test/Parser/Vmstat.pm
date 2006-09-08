package Test::Parser::Vmstat;

=head1 NAME

Test::Parser::Vmstat - Perl module to parse output from vmstat.

=head1 SYNOPSIS

 use Test::Parser::Vmstat;

 my $parser = new Test::Parser::Vmstat;
 $parser->parse($text);

=head1 DESCRIPTION

This module transforms vmstat output into a hash that can be used to generate
XML.

=head1 FUNCTIONS

Also see L<Test::Parser> for functions available from the base class.

=cut

use strict;
use warnings;
use Test::Parser;
use XML::Simple;
use Chart::Graph::Gnuplot qw(gnuplot);

@Test::Parser::Vmstat::ISA = qw(Test::Parser);
use base 'Test::Parser';

use fields qw(
              data
              time_units
              );

use vars qw( %FIELDS $AUTOLOAD $VERSION );
our $VERSION = '1.4';

=head2 new()

Creates a new Test::Parser::Vmstat instance.
Also calls the Test::Parser base class' new() routine.
Takes no arguments.

=cut

sub new {
    my $class = shift;
    my Test::Parser::Vmstat $self = fields::new($class);
    $self->SUPER::new();

    $self->name('vmstat');
    $self->type('standards');

    #
    # Vmstat data in an array.
    #
    $self->{data} = [];

    #
    # Used for plotting.
    #
    $self->{format} = 'png';
    $self->{outdir} = '.';
    $self->{time_units} = 'Minutes';

    return $self;
}

=head3 data()

Returns a hash representation of the vmstat data.

=cut
sub data {
    my $self = shift;
    if (@_) {
        $self->{data} = @_;
    }
    return {vmstat => {data => $self->{data}}};
}

=head3

Override of Test::Parser's default parse_line() routine to make it able
to parse vmstat output.

=cut
sub parse_line {
    my $self = shift;
    my $line = shift;

    #
    # Trim any leading and trailing whitespaces.
    #
    $line =~ s/^\s+//;
    chomp($line);

    my @i = split / +/, $line;
    #
    # These should ignore any header lines.
    #
    return 1 if (scalar @i != 16);
    return 1 if ($i[0] eq 'r');
    #
    # Since the first row of data is garbage, set everything to 0.
    #
    my $count = scalar @{$self->{data}};
    @i = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
            if ($count == 0);
    push @{$self->{data}}, {r => $i[0], b => $i[1], swpd => $i[2],
            free => $i[3], buff => $i[4], cache => $i[5], si => $i[6],
            so => $i[7], bi => $i[8], bo => $i[9],  in => $i[10], cs => $i[11],
            us => $i[12], sy => $i[13], id => $i[14], wa => $i[15],
            elapsed_time => $count};

    return 1;
}

=head3 plot()

Plot the data using Gnuplot.

=cut
sub plot {
    my $self = shift;
    #
    # Independent data, which we plot on the x-axis.
    #
    my @x = ();

    #
    # Procs
    #
    my %gopts_procs = (
            'title' => 'Procs',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => 'Count',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/vmstat-procs.$self->{format}"
    );
    my @r = ();
    my @b = ();
    my %dsopts_r = (
            'style' => 'lines',
            'title' => 'waiting for run time',
            'type' => 'columns',
    );
    my %dsopts_b = (
            'style' => 'lines',
            'title' => 'in uninterruptible sleep',
            'type' => 'columns',
    );

    #
    # Memory
    #
    my %gopts_memory = (
            'title' => 'Memory',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => 'Kilobytes',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/vmstat-memory.$self->{format}"
    );
    my %dsopts_buff = (
            'style' => 'lines',
            'title' => 'Buffers',
            'type' => 'columns',
    );
    my %dsopts_cache = (
            'style' => 'lines',
            'title' => 'cache',
            'type' => 'columns',
    );
    my %dsopts_free = (
            'style' => 'lines',
            'title' => 'Free',
            'type' => 'columns',
    );
    my %dsopts_swpd = (
            'style' => 'lines',
            'title' => 'Swapped',
            'type' => 'columns',
    );
    my @buff = ();
    my @cache = ();
    my @free = ();
    my @swpd = ();

    #
    # Swap
    #
    my %gopts_swap = (
            'title' => 'Swap',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => 'Kilobytes / Second',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/vmstat-swap.$self->{format}"
    );
    my %dsopts_si = (
            'style' => 'lines',
            'title' => 'in from disk',
            'type' => 'columns',
    );
    my %dsopts_so = (
            'style' => 'lines',
            'title' => 'out to disk',
            'type' => 'columns',
    );
    my @si = ();
    my @so = ();

    #
    # I/O
    #
    my %gopts_io = (
            'title' => 'I/O',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => 'Blocks / Second',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/vmstat-io.$self->{format}"
    );
    my %dsopts_bi = (
            'style' => 'lines',
            'title' => 'received from device',
            'type' => 'columns',
    );
    my %dsopts_bo = (
            'style' => 'lines',
            'title' => 'sent to device',
            'type' => 'columns',
    );
    my @bi = ();
    my @bo = ();

    #
    # Interrupts
    #
    my %gopts_in = (
            'title' => 'Interrupts',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => '# of Interrupts / Second',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/vmstat-in.$self->{format}"
    );
    my %dsopts_in = (
            'style' => 'lines',
            'title' => 'interrupts',
            'type' => 'columns',
    );
    my @in = ();

    #
    # Context Switches
    #
    my %gopts_cs = (
            'title' => 'Context Switches',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => '# of Context Switches / Second',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/vmstat-cs.$self->{format}"
    );
    my %dsopts_cs = (
            'style' => 'lines',
            'title' => 'context switches',
            'type' => 'columns',
    );
    my @cs = ();

    #
    # Processor Utilization
    #
    my %gopts_cpu = (
            'title' => 'Processor Utilization',
            'yrange' => '[0:100]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => '% Utilized',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/vmstat-cpu.$self->{format}"
    );
    my %dsopts_id = (
            'style' => 'lines',
            'title' => 'idle',
            'type' => 'columns',
    );
    my %dsopts_sy = (
            'style' => 'lines',
            'title' => 'system',
            'type' => 'columns',
    );
    my %dsopts_total = (
            'style' => 'lines',
            'title' => 'total',
            'type' => 'columns',
    );
    my %dsopts_us = (
            'style' => 'lines',
            'title' => 'user',
            'type' => 'columns',
    );
    my %dsopts_wa = (
            'style' => 'lines',
            'title' => 'wait',
            'type' => 'columns',
    );
    my @id = ();
    my @sy = ();
    my @total = ();
    my @us = ();
    my @wa = ();

    #
    # Transform the data from the hash into plottable arrays for Gnuplot.
    #
    my @a = @{$self->{data}};
    for (my $i = 0; $i < scalar @a; $i++) {
        push @x, $a[$i]->{elapsed_time};

        push @r, $a[$i]->{r};
        push @b, $a[$i]->{b};
  
        push @buff, $a[$i]->{buff};
        push @cache, $a[$i]->{cache};
        push @free, $a[$i]->{free};
        push @swpd, $a[$i]->{swpd};

        push @si, $a[$i]->{si};
        push @so, $a[$i]->{so};

        push @bi, $a[$i]->{bi};
        push @bo, $a[$i]->{bo};

        push @in, $a[$i]->{in};

        push @cs, $a[$i]->{cs};

        push @id, $a[$i]->{id};
        push @sy, $a[$i]->{sy};
        push @us, $a[$i]->{us};
        push @wa, $a[$i]->{wa};
        push @total, $id[$i] + $sy[$i] + $us[$i] + $wa[$i];
    }

    #
    # Generate charts.
    #
    gnuplot(\%gopts_procs,
        [\%dsopts_r, \@x, \@r],
        [\%dsopts_b, \@x, \@b]);
    gnuplot(\%gopts_memory,
        [\%dsopts_swpd, \@x, \@swpd],
        [\%dsopts_free, \@x, \@free],
        [\%dsopts_buff, \@x, \@buff],
        [\%dsopts_cache, \@x, \@cache]);
    gnuplot(\%gopts_swap,
        [\%dsopts_si, \@x, \@si],
        [\%dsopts_so, \@x, \@so]);
    gnuplot(\%gopts_io,
        [\%dsopts_bi, \@x, \@bi],
        [\%dsopts_bo, \@x, \@bo]);
    gnuplot(\%gopts_in,
        [\%dsopts_in, \@x, \@in]);
    gnuplot(\%gopts_cs,
        [\%dsopts_cs, \@x, \@cs]);
    gnuplot(\%gopts_cpu,
        [\%dsopts_total, \@x, \@total],
        [\%dsopts_us, \@x, \@us],
        [\%dsopts_sy, \@x, \@sy],
        [\%dsopts_id, \@x, \@id],
        [\%dsopts_wa, \@x, \@wa]);
}

=head3 to_xml()

Returns vmstat data transformed into XML.

=cut
sub to_xml {
    my $self = shift;
    my $outfile = shift;
    return XMLout({data => $self->{data}}, RootName => 'vmstat');
}

1;
__END__

=head1 AUTHOR

Mark Wong <markw@osdl.org>

=head1 COPYRIGHT

Copyright (C) 2006 Mark Wong & Open Source Development Labs, Inc.
All Rights Reserved.

This script is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Test::Parser>

=end

