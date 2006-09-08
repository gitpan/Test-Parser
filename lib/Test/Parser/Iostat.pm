package Test::Parser::Iostat;

=head1 NAME

Test::Parser::Iostat - Perl module to parse output from iostat (iostat -x).

=head1 SYNOPSIS

 use Test::Parser::Iostat;

 my $parser = new Test::Parser::Iostat;
 $parser->parse($text);

=head1 DESCRIPTION

This module transforms iostat output into a hash that can be used to generate
XML.

=head1 FUNCTIONS

Also see L<Test::Parser> for functions available from the base class.

=cut

use strict;
use warnings;
use Test::Parser;
use XML::Simple;
use Chart::Graph::Gnuplot qw(gnuplot);

@Test::Parser::Iostat::ISA = qw(Test::Parser);
use base 'Test::Parser';

use fields qw(
              device
              data
              elapsed_time
              info
              time_units
              );

use vars qw( %FIELDS $AUTOLOAD $VERSION );
our $VERSION = '1.4';

=head2 new()

Creates a new Test::Parser::Iostat instance.
Also calls the Test::Parser base class' new() routine.
Takes no arguments.

=cut

sub new {
    my $class = shift;
    my Test::Parser::Iostat $self = fields::new($class);
    $self->SUPER::new();

    $self->name('iostat');
    $self->type('standards');

    #
    # Iostat data in an array and other supporting information.
    #
    $self->{data} = [];
    $self->{info} = '';
    #
    # Start at -1 because the first increment to the value will set it to 0
    # for the first set of data.
    #
    $self->{elapsed_time} = -1;

    #
    # Used for plotting.
    #
    $self->{format} = 'png';
    $self->{outdir} = '.';
    $self->{time_units} = 'Minutes';

    return $self;
}

=head3 data()

Returns a hash representation of the iostat data.

=cut
sub data {
    my $self = shift;
    if (@_) {
        $self->{data} = @_;
    }
    return {iostat => {data => $self->{data}}};
}

=head3

Override of Test::Parser's default parse_line() routine to make it able
to parse iostat output.

=cut
sub parse_line {
    my $self = shift;
    my $line = shift;

    #
    # Trim any leading and trailing whitespaces.
    #
    chomp($line);
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;

    my @i = split / +/, $line;
    my $count = scalar @i;
    if ($count == 14) {
        #
        # This is either the iostat headers or the data.  If it's a header
        # skip to the next line and increment the counter.
        #
        if ($i[0] eq "Device:") {
            #
            # We've gone through 1 iteration of data, increment the counter.
            #
            ++$self->{elapsed_time};
            return 1;
        }
    } elsif ($count == 1) {
        #
        # This just read the device name.  The data will be on the next line.
        #
        $self->{device} = $line;
        return 1;
    } elsif ($count == 13) {
        #
        # Is there a better way to put $self->{device} in front of @i?
        #
        my @j = ();
        push @j, @i;
        @i = ();
        push @i, $self->{device};
        push @i, @j;
    } elsif ($count == 4) {
        #
        # This should be information about the OS and the date.
        #
        $self->{info} = $line;
        return 1;
    } else {
        #
        # Skip empty lines.
        #
        return 1;
    }
    #
    # If $self->{elapsed_time} == 0 then zero the data out since it's bogus.
    #
    @i = ($i[0], 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
            if ($self->{elapsed_time} == 0);
    push @{$self->{data}}, {device => $i[0], rrqm => $i[1], wrqm => $i[2],
            r => $i[3], w => $i[4], rsec => $i[5], wsec => $i[6],
            rkb => $i[7], wkb => $i[8], avgrq => $i[9], avgqu => $i[10],
            await => $i[11], svctm => $i[12], util => $i[13],
            elapsed_time => $self->{elapsed_time}};

    return 1;
}

=head3 plot()

Plot the data using Gnuplot.

=cut
sub plot {
    my $self = shift;
    #
    # List of devices to plot, if specified, else plot all devices.
    #
    my @devices = @_;
    #
    # Independent data, which we plot on the x-axis.
    #
    my @x = ();
    my @ds_rqm = ();
    my @ds_rw = ();
    my @ds_sec = ();
    my @ds_kb = ();
    my @ds_avgrq = ();
    my @ds_avgqu = ();
    my @ds_await = ();
    my @ds_svctm = ();
    my @ds_util = ();

    #
    # Read/Write requests merged per second.
    #
    my %gopts_rqm = (
            'title' => 'Read/Write Requests Merged',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => '# of Merges / Second',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => "$self->{format}",
            'output file' => "$self->{outdir}/iostat-rqm.$self->{format}"
    );
    my %dsopts_temp_rqm = (
            'style' => 'lines',
            'type' => 'columns'
    );
    #
    # Read/Write requests per second.
    #
    my %gopts_rw = (
            'title' => 'Read/Write Requests',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => 'Requests / Second',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => "$self->{format}",
            'output file' => "$self->{outdir}/iostat-rw.$self->{format}"
    );
    my %dsopts_temp_rw = (
            'style' => 'lines',
            'type' => 'columns'
    );
    #
    # Read/Write sectors per second.
    #
    my %gopts_sec = (
            'title' => 'Read/Write Sectors',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => 'Sectors / Second',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => "$self->{format}",
            'output file' => "$self->{outdir}/iostat-sec.$self->{format}"
    );
    my %dsopts_temp_sec = (
            'style' => 'lines',
            'type' => 'columns'
    );
    #
    # Read/Write kilobytes per second.
    #
    my %gopts_kb = (
            'title' => 'Read/Write Kilobytes',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => 'Kilobytes / Second',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => "$self->{format}",
            'output file' => "$self->{outdir}/iostat-kb.$self->{format}"
    );
    my %dsopts_temp_kb = (
            'style' => 'lines',
            'type' => 'columns'
    );
    #
    # Average request size.
    #
    my %gopts_avgrq = (
            'title' => 'Average Request Size',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => 'Sectors',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => "$self->{format}",
            'output file' => "$self->{outdir}/iostat-avgrq.$self->{format}"
    );
    my %dsopts_temp_avgrq = (
            'style' => 'lines',
            'type' => 'columns'
    );
    #
    # Average queue length
    #
    my %gopts_avgqu = (
            'title' => 'Average Queue Length',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => '#',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => "$self->{format}",
            'output file' => "$self->{outdir}/iostat-avgqu.$self->{format}"
    );
    my %dsopts_temp_avgqu = (
            'style' => 'lines',
            'type' => 'columns'
    );
    #
    # Averate request time
    #
    my %gopts_await = (
            'title' => 'Average Request Time',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => 'Milliseconds',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => "$self->{format}",
            'output file' => "$self->{outdir}/iostat-await.$self->{format}"
    );
    my %dsopts_temp_await = (
            'style' => 'lines',
            'type' => 'columns'
    );
    #
    # Averate service time
    #
    my %gopts_svctm = (
            'title' => 'Average Service Time',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => 'Milliseconds',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => "$self->{format}",
            'output file' => "$self->{outdir}/iostat-svctm.$self->{format}"
    );
    my %dsopts_temp_svctm = (
            'style' => 'lines',
            'type' => 'columns'
    );
    #
    # Utilization
    #
    my %gopts_util = (
            'title' => '% Utilization',
            'yrange' => '[0:100]',
            'x-axis label' => "Elapsed Time ($self->{time_units})",
            'y-axis label' => 'Percentage',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => "$self->{format}",
            'output file' => "$self->{outdir}/iostat-util.$self->{format}"
    );
    my %dsopts_temp_util = (
            'style' => 'lines',
            'type' => 'columns'
    );

    #
    # Transform the data from the hash into another hash of arrays.
    # There has to be a better way to transform this data.  XQuery???
    #
    my @a = @{$self->{data}};
    my $dev = ();
    for (my $i = 0; $i < scalar @a; $i++) {
        for my $k (keys %{$a[$i]}) {
            next if ($k eq 'device');
            push @{$dev->{$a[$i]->{device}}->{$k}}, $a[$i]->{$k};
        }
    }
    #
    # Build the data set arrays to be plotted.
    #
    my $h;
    #
    # Created data sets for all devices or use the list of devices passed to
    # the function.
    #
    unless (@devices) {
        for my $k (sort keys %$dev) {
            push @devices, $k;
        }
    }
    for my $k (@devices) {
        #
        # Skip to the next device if we don't have a reference for it.
        #
        unless ($dev->{$k}) {
            print "Device '$k' does not exist.\n";
            next;
        }
        #
        # Build the x-axis values once.
        #
        push @x, @{$dev->{$k}->{elapsed_time}} if (scalar @x == 0);
        #
        # r/w requested merged per second
        #
        $h = ();
        $h->{title} = "$k rrqm";
        for my $kk (keys %dsopts_temp_rqm) {
            $h->{$kk} = $dsopts_temp_rqm{$kk};
        }
        push @ds_rqm, [\%{$h}, \@x, \@{$dev->{$k}->{rrqm}}];

        $h = ();
        $h->{title} = "$k wrqm";
        for my $kk (keys %dsopts_temp_rqm) {
            $h->{$kk} = $dsopts_temp_rqm{$kk};
        }
        push @ds_rqm, [\%{$h}, \@x, \@{$dev->{$k}->{wrqm}}];
        #
        # r/w per second
        #
        $h = ();
        $h->{title} = "$k r/s";
        for my $kk (keys %dsopts_temp_rw) {
            $h->{$kk} = $dsopts_temp_rw{$kk};
        }
        push @ds_rw, [\%{$h}, \@x, \@{$dev->{$k}->{r}}];

        $h = ();
        $h->{title} = "$k w/s";
        for my $kk (keys %dsopts_temp_rw) {
            $h->{$kk} = $dsopts_temp_rw{$kk};
        }
        push @ds_rw, [\%{$h}, \@x, \@{$dev->{$k}->{w}}];
        #
        # r/w sectors per second
        #
        $h = ();
        $h->{title} = "$k rsec";
        for my $kk (keys %dsopts_temp_sec) {
            $h->{$kk} = $dsopts_temp_sec{$kk};
        }
        push @ds_sec, [\%{$h}, \@x, \@{$dev->{$k}->{rsec}}];

        $h = ();
        $h->{title} = "$k wsec";
        for my $kk (keys %dsopts_temp_sec) {
            $h->{$kk} = $dsopts_temp_sec{$kk};
        }
        push @ds_sec, [\%{$h}, \@x, \@{$dev->{$k}->{wsec}}];
        #
        # r/w kilobytes per second
        #
        $h = ();
        $h->{title} = "$k rkb";
        for my $kk (keys %dsopts_temp_kb) {
            $h->{$kk} = $dsopts_temp_kb{$kk};
        }
        push @ds_kb, [\%{$h}, \@x, \@{$dev->{$k}->{rkb}}];

        $h = ();
        $h->{title} = "$k wkb";
        for my $kk (keys %dsopts_temp_kb) {
            $h->{$kk} = $dsopts_temp_kb{$kk};
        }
        push @ds_kb, [\%{$h}, \@x, \@{$dev->{$k}->{wkb}}];
        #
        # avgrq-sz
        #
        $h = ();
        $h->{title} = $k;
        for my $kk (keys %dsopts_temp_avgrq) {
            $h->{$kk} = $dsopts_temp_avgrq{$kk};
        }
        push @ds_avgrq, [\%{$h}, \@x, \@{$dev->{$k}->{avgrq}}];
        #
        # avgqu-sz
        #
        $h = ();
        $h->{title} = $k;
        for my $kk (keys %dsopts_temp_avgqu) {
            $h->{$kk} = $dsopts_temp_avgqu{$kk};
        }
        push @ds_avgqu, [\%{$h}, \@x, \@{$dev->{$k}->{avgqu}}];
        #
        # await
        #
        $h = ();
        $h->{title} = $k;
        for my $kk (keys %dsopts_temp_await) {
            $h->{$kk} = $dsopts_temp_await{$kk};
        }
        push @ds_await, [\%{$h}, \@x, \@{$dev->{$k}->{await}}];
        #
        # svctm
        #
        $h = ();
        $h->{title} = $k;
        for my $kk (keys %dsopts_temp_svctm) {
            $h->{$kk} = $dsopts_temp_svctm{$kk};
        }
        push @ds_svctm, [\%{$h}, \@x, \@{$dev->{$k}->{svctm}}];
        #
        # util
        #
        $h = ();
        $h->{title} = $k;
        for my $kk (keys %dsopts_temp_util) {
            $h->{$kk} = $dsopts_temp_util{$kk};
        }
        push @ds_util, [\%{$h}, \@x, \@{$dev->{$k}->{util}}];
    } 

    #
    # Generate charts.
    #
    gnuplot(\%gopts_rqm, @ds_rqm);
    gnuplot(\%gopts_rw, @ds_rw);
    gnuplot(\%gopts_sec, @ds_sec);
    gnuplot(\%gopts_kb, @ds_kb);
    gnuplot(\%gopts_avgrq, @ds_avgrq);
    gnuplot(\%gopts_avgqu, @ds_avgqu);
    gnuplot(\%gopts_await, @ds_await);
    gnuplot(\%gopts_svctm, @ds_svctm);
    gnuplot(\%gopts_util, @ds_util);
}

=head3 to_xml()

Returns vmstat data transforms into XML.

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

