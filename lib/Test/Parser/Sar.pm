package Test::Parser::Sar;

=head1 NAME

Test::Parser::Sar - Perl module to parse output from sar.

=head1 SYNOPSIS

 use Test::Parser::Sar;

 my $parser = new Test::Parser::Sar;
 $parser->parse($text);

=head1 DESCRIPTION

This module transforms sar output into a hash that can be used to generate
XML.

=head1 FUNCTIONS

Also see L<Test::Parser> for functions available from the base class.

=cut

use strict;
use warnings;
use Test::Parser;
use XML::Simple;
use Chart::Graph::Gnuplot qw(gnuplot);
use File::Basename;

@Test::Parser::Sar::ISA = qw(Test::Parser);
use base 'Test::Parser';

use fields qw(
              time_units
              info
              proc_s
              cpu
              cswch_s
              inode
              intr
              intr_s
              io_tr
              io_bd
              memory
              memory_usage
              net_ok
              net_err
              net_sock
              paging
              queue
              swapping
              );

use vars qw( %FIELDS $AUTOLOAD $VERSION );
our $VERSION = '1.4';

=head2 new()

Creates a new Test::Parser::Sar instance.
Also calls the Test::Parser base class' new() routine.
Takes no arguments.

=cut

sub new {
    my $class = shift;
    my Test::Parser::Sar $self = fields::new($class);
    $self->SUPER::new();

    $self->name('sar');
    $self->type('standards');

    #
    # Sar data.
    #
    $self->{info} = '';
    $self->{proc_s} = ();
    $self->{cpu} = ();
    $self->{cswch_s} = ();
    $self->{inode} = ();
    $self->{intr} = ();
    $self->{intr_s} = ();
    $self->{io_tr} = ();
    $self->{io_bd} = ();
    $self->{memory} = ();
    $self->{memory_usage} = ();
    $self->{net_ok} = ();
    $self->{net_err} = ();
    $self->{net_sock} = ();
    $self->{paging} = ();
    $self->{queue} = ();
    $self->{swapping} = ();

    #
    # Used for plotting.
    #
    $self->{format} = 'png';
    $self->{outdir} = '.';
    $self->{time_units} = 'Minutes';

    return $self;
}

=head3 data()

Returns a hash representation of the sar data.

=cut
sub data {
    my $self = shift;
    if (@_) {
        $self->{data} = @_;
    }
    return {
            sar => {
                    proc_s => {data => $self->{proc_s}},
                    cswch_s => {data => $self->{cswch_s}},
                    cpu => {data => $self->{cpu}},
                    inode => {data => $self->{inode}},
                    intr => {data => $self->{intr}},
                    intr_s => {data => $self->{intr_s}},
                    io => {
                            tr => {data => $self->{io_tr}},
                            bd => {data => $self->{io_bd}}},
                    memory => {data => $self->{memory}},
                    memory_usage => {data => $self->{memory_usage}},
                    paging => {data => $self->{paging}},
                    network => {
                            ok => {data => $self->{net_ok}},
                            err => {data => $self->{net_err}},
                            sock => {data => $self->{net_sock}}},
                    queue => {data => $self->{queue}},
                    swapping => {data => $self->{swapping}}}};
}

=head3

Override of Test::Parser's default parse() routine to make it able
to parse sar output.  Support only reading from a file until a better
parsing algorithm comes along.

=cut
sub parse {
    #
    # TODO
    # Make this handle GLOBS and stuff like the parent class.
    #
    my $self = shift;
    my $input = shift or return undef;
    my ($name, $path) = @_;

    my $retval = 1;

    if (!ref($input) && -f $input) {
        $name ||= basename($input);
        $path ||= dirname($input);

        open (FILE, "< $input")
                or warn "Could not open '$input' for reading:  $!\n"
                and return undef;
        while (<FILE>) {
            chomp($_);
            my @data = split / +/, $_;
            my $count = scalar @data;
            #
            # Capture the interrupts per processor.  sar -I SUM -P ALL
            # This is hard because the number of columns varies depending on the
            # number of interrupt addresses.
            #
            # Let's hope we can always determine this is when the 2nd column
            # starts with CPU and the next column is i000/s, but we'll try to
            # pattern match the beginning 'i' and ending '/s' parts.
            #
            if ($count > 2 and $data[1] eq 'CPU' and $data[2] =~ /^i.*\/s$/) {
                while (my $line = <FILE>) {
                    chomp($line);
                    my @data2 = split / +/, $line;
                    last if (scalar @data2 == 0 or $data2[0] eq 'Average:');
                    my $h = {time => $data2[0], cpu => $data2[1]};
                    for (my $i = 2; $i < $count; $i++) {
                        $data[$i] =~ /^(i.*)\/s$/;
                        $h->{$1} = $data2[$i];
                    }
                    push @{$self->{intr}}, $h;
                }
            } elsif ($count == 2) {
                if ($data[1] eq 'proc/s') {
                    #
                    # Process creation activity.  sar -c
                    # Keep reading until we hit an empty line.
                    #
                    while (my $line = <FILE>) {
                        chomp($line);
                        @data = split / +/, $line;
                        if (scalar @data == 2 and $data[0] ne 'Average:') {
                            push @{$self->{proc_s}},
                                    {time => $data[0], proc_s => $data[1]};
                        } else {
                            last;
                        }
                    }
                } elsif ($data[1] eq 'cswch/s') {
                    #
                    # System (context) switching activity.  sar -w
                    # Keep reading until we hit an empty line.
                    #
                    while (my $line = <FILE>) {
                        chomp($line);
                        @data = split / +/, $line;
                        if (scalar @data == 2 and $data[0] ne 'Average:') {
                            push @{$self->{cswch_s}},
                                    {time => $data[0], cswch_s => $data[1]};
                        } else {
                            last;
                        }
                    }
                }
            } elsif ($count == 3) {
                if ($data[1] eq 'INTR') {
                    #
                    # Total interrupts.  sar -I SUM
                    # Keep reading until we hit an empty line.
                    #
                    while (my $line = <FILE>) {
                        chomp($line);
                        @data = split / +/, $line;
                        if (scalar @data == 3 and $data[0] ne 'Average:' and
                                $data[1] eq 'sum') {
                            push @{$self->{intr_s}},
                                    {time => $data[0], intr_s => $data[2]};
                        } else {
                            last;
                        }
                    }
                } elsif ($data[1] eq 'pswpin/s' and $data[2] eq 'pswpout/s') {
                    #
                    # Swapping statistics.  sar -W
                    # Keep reading until we hit an empty line.
                    #
                    while (my $line = <FILE>) {
                        chomp($line);
                        @data = split / +/, $line;
                        if (scalar @data == 3 and $data[0] ne 'Average:') {
                            push @{$self->{swapping}},
                                    {time => $data[0],
                                    pswpin_s => $data[1],
                                    pswpout_s => $data[2]};
                        } else {
                            last;
                        }
                    }
                }
            } elsif ($count == 4) {
                if ($data[1] eq 'frmpg/s') {
                    #
                    # Memory statistics.  sar -R
                    # Keep reading until we hit an empty line.
                    #
                    while (my $line = <FILE>) {
                        chomp($line);
                        @data = split / +/, $line;
                        if (scalar @data == 4 and $data[0] ne 'Average:') {
                            push @{$self->{memory}},
                                    {time => $data[0],
                                    frmpg_s => $data[1],
                                    bufpg_s => $data[2],
                                    campg_s => $data[3]};
                        } else {
                            last;
                        }
                    }
                }
            } elsif ($count == 5) {
                if ($data[1] eq 'DEV') {
                    #
                    # I/O block device statistics.  sar -d
                    # Keep reading until we hit an empty line.
                    #
                    while (my $line = <FILE>) {
                        chomp($line);
                        @data = split / +/, $line;
                        if (scalar @data == 5 and $data[0] ne 'Average:') {
                            push @{$self->{io_bd}},
                                    {time => $data[0],
                                    dev => $data[1],
                                    tps => $data[2],
                                    rd_sec_s => $data[3],
                                    wr_sec_s => $data[4]};
                        } else {
                            last;
                        }
                    }
                } elsif ($data[1] eq 'pgpgin/s') {
                    #
                    # Paging statistics.  sar -B
                    # Keep reading until we hit an empty line.
                    #
                    while (my $line = <FILE>) {
                        chomp($line);
                        @data = split / +/, $line;
                        if (scalar @data == 5 and $data[0] ne 'Average:') {
                            push @{$self->{paging}},
                                    {time => $data[0],
                                    pgpgin_s => $data[1],
                                    pgpgout_s => $data[2],
                                    fault_s => $data[3],
                                    majflt_s => $data[4]};
                        } else {
                            last;
                        }
                    }
                }
            } elsif ($count == 6) {
                if ($data[1] eq 'tps') {
                    #
                    # I/O transfer rate statistics.  sar -b
                    # Keep reading until we hit an empty line.
                    #
                    while (my $line = <FILE>) {
                        chomp($line);
                        @data = split / +/, $line;
                        if (scalar @data == 6 and $data[0] ne 'Average:') {
                            push @{$self->{io_tr}},
                                    {time => $data[0],
                                    tps => $data[1],
                                    rtps => $data[2],
                                    wtps => $data[3],
                                    bread_s => $data[4],
                                    bwrtn_s => $data[5]};
                        } else {
                            last;
                        }
                    }
                } elsif ($data[1] eq 'totsck') {
                    #
                    # Part of the network statitics, sockets.  sar -n FULL
                    # Keep reading until we hit an empty line.
                    #
                    while (my $line = <FILE>) {
                        chomp($line);
                        @data = split / +/, $line;
                        if (scalar @data == 6 and $data[0] ne 'Average:') {
                            push @{$self->{net_sock}},
                                    {time => $data[0],
                                    totsck => $data[1],
                                    tcpsck => $data[2],
                                    udpsck => $data[3],
                                    rawsck => $data[4],
                                    'ip-frag' => $data[5]};
                        } else {
                            last;
                        }
                    }
                } elsif ($data[1] eq 'runq-sz') {
                    #
                    # Queue and load averages.  sar -q
                    # Keep reading until we hit an empty line.
                    #
                    while (my $line = <FILE>) {
                        chomp($line);
                        @data = split / +/, $line;
                        if (scalar @data == 6 and $data[0] ne 'Average:') {
                            push @{$self->{queue}},
                                    {time => $data[0],
                                    'runq-sz' => $data[1],
                                    'plist-sz' => $data[2],
                                    'ldavg-1' => $data[3],
                                    'ldavg-5' => $data[4],
                                    'ldavg-15' => $data[5]};
                        } else {
                            last;
                        }
                    }
                }
            } elsif ($count == 7) {
                if ($data[1] eq 'CPU') {
                    #
                    # CPU utilization report.  sar -u
                    # Keep reading until we hit an empty line.
                    #
                    while (my $line = <FILE>) {
                        chomp($line);
                        @data = split / +/, $line;
                        if (scalar @data == 7 and $data[0] ne 'Average:') {
                            push @{$self->{cpu}},
                                    {time => $data[0],
                                    cpu => $data[1],
                                    user => $data[2],
                                    nice => $data[3],
                                    system => $data[4],
                                    iowait => $data[5],
                                    idle => $data[6]};
                        } else {
                            last;
                        }
                    }
                }
            } elsif ($count == 9) {
                if ($data[1] eq 'IFACE') {
                    #
                    # Part of the network statitics, ok packets.  sar -n FULL
                    # Keep reading until we hit an empty line.
                    #
                    while (my $line = <FILE>) {
                        chomp($line);
                        @data = split / +/, $line;
                        if (scalar @data == 9 and $data[0] ne 'Average:') {
                            push @{$self->{net_ok}},
                                    {time => $data[0],
                                    iface => $data[1],
                                    rxpck_s => $data[2],
                                    txpck_s => $data[3],
                                    rxbyt_s => $data[4],
                                    txbyt_s => $data[5],
                                    rxcmp_s => $data[6],
                                    txcmp_s => $data[7],
                                    rxmcst_s => $data[8]};
                        } else {
                            last;
                        }
                    }
                }
            } elsif ($count == 10) {
                if ($data[1] eq 'kbmemfree') {
                    #
                    # Memory and swap space utilization statistics.  sar -r
                    # Keep reading until we hit an empty line.
                    #
                    while (my $line = <FILE>) {
                        chomp($line);
                        @data = split / +/, $line;
                        if (scalar @data == 10 and $data[0] ne 'Average:') {
                            push @{$self->{memory_usage}},
                                    {time => $data[0],
                                    kbmemfree => $data[1],
                                    kbmemused => $data[2],
                                    memused => $data[3],
                                    kbbuffers => $data[4],
                                    kbcached => $data[5],
                                    kbswpfree => $data[6],
                                    kbswpused => $data[7],
                                    swpused => $data[8],
                                    kbswpcad => $data[9]};
                        } else {
                            last;
                        }
                    }
                } elsif ($data[1] eq 'dentunusd') {
                    #
                    # Inode, file and other kernel statistics.  sar -v
                    # Keep reading until we hit an empty line.
                    #
                    while (my $line = <FILE>) {
                        chomp($line);
                        @data = split / +/, $line;
                        if (scalar @data == 10 and $data[0] ne 'Average:') {
                            push @{$self->{inode}},
                                    {time => $data[0],
                                    dentunusd => $data[1],
                                    'file-sz' => $data[2],
                                    'inode-sz' => $data[3],
                                    'super-sz' => $data[4],
                                    'psuper-sz' => $data[5],
                                    'dquot-sz' => $data[6],
                                    'pdquot-sz' => $data[7],
                                    'rtsig-sz' => $data[8],
                                    'prtsig-sz' => $data[9]};
                        } else {
                            last;
                        }
                    }
                }
            } elsif ($count == 11) {
                if ($data[1] eq 'IFACE') {
                    #
                    # Part of the network statitics, error packets.  sar -n FULL
                    # Keep reading until we hit an empty line.
                    #
                    while (my $line = <FILE>) {
                        chomp($line);
                        @data = split / +/, $line;
                        if (scalar @data == 11 and $data[0] ne 'Average:') {
                            push @{$self->{net_err}},
                                    {time => $data[0],
                                    iface => $data[1],
                                    rxerr_s => $data[2],
                                    txerr_s => $data[3],
                                    coll_s => $data[4],
                                    rxdrop_s => $data[5],
                                    txdrop_s => $data[6],
                                    txcarr_s => $data[7],
                                    rxfram_s => $data[8],
                                    rxfifo_s => $data[9],
                                    txfifo_s => $data[10]};
                        } else {
                            last;
                        }
                    }
                }
            }
        }
        close(FILE);
    }
    $self->{name} = $name;
    $self->{path} = $path;

    return $retval;

    return 1;
}

=head3 plot()

Plot the data using Gnuplot.

=cut
sub plot {
    my $self = shift;
    #
    # X- and Y-axis data.
    #
    my @x;
    my @y;

    my $h;
    my %dsopts = ();

    #
    # Process creation activity
    #
    my %gopts_proc_s = (
            'title' => 'Processes Created',
            'yrange' => '[0:]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Processes Created / Second',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-proc_s.$self->{format}"
    );
    %dsopts = (
            'style' => 'lines',
            'title' => 'proc/s',
            'type' => 'columns',
    );
    @x = ();
    @y = ();
    for my $i (@{$self->{proc_s}}) {
        push @x, $i->{time};
        push @y, $i->{proc_s};
    }
    gnuplot(\%gopts_proc_s, [\%dsopts, \@x, \@y]);
    #
    # System swtching activity
    #
    my %gopts_cswch_s = (
            'title' => 'Context Switches',
            'yrange' => '[0:]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Context Switches / Second',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-cswch_s.$self->{format}"
    );
    %dsopts = (
            'style' => 'lines',
            'title' => 'proc/s',
            'type' => 'columns',
    );
    @x = ();
    @y = ();
    for my $i (@{$self->{cswch_s}}) {
        push @x, $i->{time};
        push @y, $i->{cswch_s};
    }
    gnuplot(\%gopts_cswch_s, [\%dsopts, \@x, \@y]);
    #
    # Process utilization
    #
    my %gopts_cpu = (
            'title' => 'Processor Utilization',
            'yrange' => '[0:100]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Percentage',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-cpu.$self->{format}"
    );
    %dsopts = (
            'style' => 'lines',
            'type' => 'columns',
    );
    my $cpu = ();
    for my $i (@{$self->{cpu}}) {
        #
        # It's silly to save time for each cpu but it's representative of the
        # raw data and it's simple to implement this way.
        #
        push @{$cpu->{$i->{cpu}}->{time}}, $i->{time};
        push @{$cpu->{$i->{cpu}}->{user}}, $i->{user};
        push @{$cpu->{$i->{cpu}}->{idle}}, $i->{idle};
        push @{$cpu->{$i->{cpu}}->{iowait}}, $i->{iowait};
        push @{$cpu->{$i->{cpu}}->{nice}}, $i->{nice};
        push @{$cpu->{$i->{cpu}}->{system}}, $i->{system};
    }
    #
    # Use y as an array of datasets as opposed to y-axis values.
    #
    @y = ();
    for my $i (sort keys %$cpu) {
        for my $j (sort keys %{$cpu->{$i}}) {
            #
            # Don't need to plot time vs. time.
            #
            next if ($j eq 'time');
            $h = ();
            for my $kk (keys %dsopts) {
                $h->{$kk} = $dsopts{$kk};
            }
            $h->{title} = "cpu $i $j";
            push @y, [\%{$h}, \@{$cpu->{$i}->{time}}, \@{$cpu->{$i}->{$j}}];
        }
    }
    gnuplot(\%gopts_cpu, @y);
    #
    # Inode and file tables.
    #
    %dsopts = (
            'style' => 'lines',
            'title' => 'proc/s',
            'type' => 'columns',
    );
    my %gopts_dentunusd = (
            'title' => 'Unused Directory Cache Entries',
            'yrange' => '[0:]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Number of Entries',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-dentunusd.$self->{format}"
    );
    @x = ();
    @y = ();
    for my $i (@{$self->{inode}}) {
        push @x, $i->{time};
        push @y, $i->{dentunusd};
    }
    gnuplot(\%gopts_dentunusd, [\%dsopts, \@x, \@y]);

    my %gopts_file_sz = (
            'title' => 'File Handles',
            'yrange' => '[0:]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Number of File Handles',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-file-sz.$self->{format}"
    );
    @y = ();
    for my $i (@{$self->{inode}}) {
        push @y, $i->{'file-sz'};
    }
    gnuplot(\%gopts_file_sz, [\%dsopts, \@x, \@y]);

    my %gopts_inode_sz = (
            'title' => 'Inode Handlers',
            'yrange' => '[0:]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Number of Inode Handlers',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-inode-sz.$self->{format}"
    );
    @y = ();
    for my $i (@{$self->{inode}}) {
        push @y, $i->{'inode-sz'};
    }
    gnuplot(\%gopts_inode_sz, [\%dsopts, \@x, \@y]);

    my %gopts_super_sz = (
            'title' => 'Super Block Handlers',
            'yrange' => '[0:]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Number of Super Block Handlers',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-super-sz.$self->{format}"
    );
    @y = ();
    for my $i (@{$self->{inode}}) {
        push @y, $i->{'super-sz'};
    }
    gnuplot(\%gopts_super_sz, [\%dsopts, \@x, \@y]);

    my %gopts_dquot_sz = (
            'title' => 'Disk Quota Entries',
            'yrange' => '[0:]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Number of Disk Quota Entries',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-dquot-sz.$self->{format}"
    );
    @y = ();
    for my $i (@{$self->{inode}}) {
        push @y, $i->{'dquot-sz'};
    }
    gnuplot(\%gopts_dquot_sz, [\%dsopts, \@x, \@y]);

    my %gopts_rtsig_sz = (
            'title' => 'RT Signals',
            'yrange' => '[0:]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Number of Queued RT Signals',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-rtsig-sz.$self->{format}"
    );
    @y = ();
    for my $i (@{$self->{inode}}) {
        push @y, $i->{'rtsig-sz'};
    }
    gnuplot(\%gopts_rtsig_sz, [\%dsopts, \@x, \@y]);

    my %gopts_p = (
            'title' => 'Inode Percengtages',
            'yrange' => '[0:100]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Percentrage',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-inode-p.$self->{format}"
    );
    my $h1;
    my $h2;
    my $h3;
    for my $kk (keys %dsopts) {
        $h1->{$kk} = $dsopts{$kk};
        $h2->{$kk} = $dsopts{$kk};
        $h3->{$kk} = $dsopts{$kk};
    }
    $h1->{title} = '%super-sz';
    $h2->{title} = '%dquot-sz';
    $h3->{title} = '%rtsig-sz';
    my @y1 = ();
    my @y2 = ();
    my @y3 = ();
    for my $i (@{$self->{inode}}) {
        push @y1, $i->{'psuper-sz'};
        push @y2, $i->{'pdquot-sz'};
        push @y3, $i->{'prtsig-sz'};
    }
    gnuplot(\%gopts_p,
            [\%{$h1}, \@x, \@y1],
            [\%{$h2}, \@x, \@y2],
            [\%{$h3}, \@x, \@y3]);
    #
    # Interrupts/s
    #
    my %gopts_intr_s = (
            'title' => 'Interrupts',
            'yrange' => '[0:]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Interrupts / Second',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-intr_s.$self->{format}"
    );
    %dsopts = (
            'style' => 'lines',
            'title' => 'proc/s',
            'type' => 'columns',
    );
    @x = ();
    @y = ();
    for my $i (@{$self->{intr_s}}) {
        push @x, $i->{time};
        push @y, $i->{intr_s};
    }
    gnuplot(\%gopts_intr_s, [\%dsopts, \@x, \@y]);
    #
    # Interrupts
    #
    my %gopts_intr = (
            'title' => 'Interrupts',
            'yrange' => '[0:]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Interrupts / Second',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-intr.$self->{format}"
    );
    %dsopts = (
            'style' => 'lines',
            'type' => 'columns',
    );
    my $intr = ();
    for my $i (@{$self->{intr}}) {
        for my $j (sort keys %$i) {
            next if ($j eq 'cpu');
            push @{$intr->{$i->{cpu}}->{$j}}, $i->{$j};
        }
    }
    #
    # Use y as an array of datasets as opposed to y-axis values.
    #
    @y = ();
    for my $i (sort keys %$intr) {
        for my $j (sort keys %{$intr->{$i}}) {
            #
            # Don't need to plot time vs. time.
            #
            next if ($j eq 'time');
            $h = ();
            for my $kk (keys %dsopts) {
                $h->{$kk} = $dsopts{$kk};
            }
            $h->{title} = "cpu $i : intr $j";
            push @y, [\%{$h}, \@{$intr->{$i}->{time}}, \@{$intr->{$i}->{$j}}];
        }
    }
    gnuplot(\%gopts_intr, @y);
    #
    # Memory statistics
    #
    my %gopts_memory = (
            'title' => 'Memory Statistics',
            'yrange' => '[0:]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Pages / Second',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-memory.$self->{format}"
    );
    %dsopts = (
            'style' => 'lines',
            'title' => 'proc/s',
            'type' => 'columns',
    );
    @x = ();
    @y = ();
    my $memory = ();
    for my $i (@{$self->{memory}}) {
        for my $k (sort keys %{$i}) {
            if ($k eq 'time') {
                push @x, $i->{time};
            } else {
                push @{$memory->{$k}}, $i->{$k};
            }
        }
    }
    for my $i (keys %$memory) {
        $h = ();
        for my $kk (keys %dsopts) {
            $h->{$kk} = $dsopts{$kk};
        }
        $h->{title} = "$i";
        push @y, [\%{$h}, \@x, \@{$memory->{$i}}];
    }
    gnuplot(\%gopts_memory, @y);
    #
    # Memory and swap space utilization.
    #
    my %gopts_kbmem = (
            'title' => 'Memory Usage',
            'yrange' => '[0:]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Kilobytes',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-memory-usage.$self->{format}"
    );
    %dsopts = (
            'style' => 'lines',
            'title' => 'proc/s',
            'type' => 'columns',
    );
    @x = ();
    @y = ();
    my $memory_usage = ();
    for my $i (@{$self->{memory_usage}}) {
        for my $k (sort keys %{$i}) {
            if ($k eq 'time') {
                push @x, $i->{time};
            } else {
                push @{$memory_usage->{$k}}, $i->{$k};
            }
        }
    }
    for my $i (keys %$memory_usage) {
        #
        # We only want to chart data that start with 'kb' because those numbers
        # are in kilobytes.  The others are percentages.
        #
        next unless $i =~ /^kb/;
        $h = ();
        for my $kk (keys %dsopts) {
            $h->{$kk} = $dsopts{$kk};
        }
        $h->{title} = "$i";
        push @y, [\%{$h}, \@x, \@{$memory_usage->{$i}}];
    }
    gnuplot(\%gopts_kbmem, @y);

    $gopts_kbmem{'y-axis label'} = 'Percentage';
    $gopts_kbmem{'output file'} =
            "$self->{outdir}/sar-memory-usage-p.$self->{format}";
    @y = ();
    for my $i (sort keys %$memory_usage) {
        #
        # We only want to chart data that don't start with 'kb' because those
        # numbers are in percentages.
        #
        next if $i =~ /^kb/;
        $h = ();
        for my $kk (keys %dsopts) {
            $h->{$kk} = $dsopts{$kk};
        }
        $h->{title} = "$i";
        push @y, [\%{$h}, \@x, \@{$memory_usage->{$i}}];
    }
    gnuplot(\%gopts_kbmem, @y);
    #
    # Paging statistics
    #
    my %gopts_paging = (
            'title' => 'Paging Statistics',
            'yrange' => '[0:]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Pages / Second',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-paging.$self->{format}"
    );
    %dsopts = (
            'style' => 'lines',
            'title' => 'proc/s',
            'type' => 'columns',
    );
    @x = ();
    @y = ();
    my $paging = ();
    for my $i (@{$self->{paging}}) {
        for my $k (sort keys %{$i}) {
            if ($k eq 'time') {
                push @x, $i->{time};
            } else {
                push @{$paging->{$k}}, $i->{$k};
            }
        }
    }
    for my $i (keys %$paging) {
        $h = ();
        for my $kk (keys %dsopts) {
            $h->{$kk} = $dsopts{$kk};
        }
        $h->{title} = "$i";
        push @y, [\%{$h}, \@x, \@{$paging->{$i}}];
    }
    gnuplot(\%gopts_paging, @y);
    #
    # TODO
    # Chart network data.
    #
    # TODO
    # Chart queue data.
    #
    # Swapping statistics
    #
    my %gopts_swapping = (
            'title' => 'Swapping Statistics',
            'yrange' => '[0:]',
            'x-axis label' => 'Time',
            'y-axis label' => 'Pages / Second',
            'xdata' => 'time',
            'extra_opts' => 'set grid xtics ytics',
            'timefmt' => '%H:%M:%S',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/sar-swapping.$self->{format}"
    );
    %dsopts = (
            'style' => 'lines',
            'title' => 'proc/s',
            'type' => 'columns',
    );
    @x = ();
    @y = ();
    my $swapping = ();
    for my $i (@{$self->{swapping}}) {
        for my $k (sort keys %{$i}) {
            if ($k eq 'time') {
                push @x, $i->{time};
            } else {
                push @{$swapping->{$k}}, $i->{$k};
            }
        }
    }
    for my $i (keys %$swapping) {
        $h = ();
        for my $kk (keys %dsopts) {
            $h->{$kk} = $dsopts{$kk};
        }
        $h->{title} = "$i";
        push @y, [\%{$h}, \@x, \@{$swapping->{$i}}];
    }
    gnuplot(\%gopts_swapping, @y);
}

=head3 to_xml()

Returns sar data transformed into XML.

=cut
sub to_xml {
    my $self = shift;
    my $outfile = shift;
    return XMLout({            
            proc_s => {data => $self->{proc_s}},
            cswch_s => {data => $self->{cswch_s}},
            cpu => {data => $self->{cpu}},
            inode => {data => $self->{inode}},
            intr => {data => $self->{intr}},
            intr_s => {data => $self->{intr_s}},
            io => {
                    tr => {data => $self->{io_tr}},
                    bd => {data => $self->{io_bd}}},
            memory => {data => $self->{memory}},
            memory_usage => {data => $self->{memory_usage}},
            paging => {data => $self->{paging}},
            network => {
                    ok => {data => $self->{net_ok}},
                    err => {data => $self->{net_err}},
                    sock => {data => $self->{net_sock}}},
            queue => {data => $self->{queue}},
            swapping => {data => $self->{swapping}} },
            RootName => 'sar');
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

