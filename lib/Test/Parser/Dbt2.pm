package Test::Parser::Dbt2;

=head1 NAME

Test::Parser::Dbt2 - Perl module to parse output files from a DBT-2 test run.

=head1 SYNOPSIS

 use Test::Parser::Dbt2;

 my $parser = new Test::Parser::Dbt2;
 $parser->parse($text);

=head1 DESCRIPTION

This module transforms DBT-2 output into a hash that can be used to generate
XML.

=head1 FUNCTIONS

Also see L<Test::Parser> for functions available from the base class.

=cut

use strict;
use warnings;
use Chart::Graph::Gnuplot qw(gnuplot);
use CGI;
use POSIX qw(ceil floor);
use Test::Parser;
use Test::Parser::Iostat;
use Test::Parser::Oprofile;
use Test::Parser::PgOptions;
use Test::Parser::Readprofile;
use Test::Parser::Sar;
use Test::Parser::Sysctl;
use Test::Parser::Vmstat;
use XML::Simple;

@Test::Parser::Dbt2::ISA = qw(Test::Parser);
use base 'Test::Parser';

use fields qw(
              cmdline
              customer
              data
              dist_d
              dist_n
              dist_o
              dist_p
              dist_s
              district
              duration
              db
              history
              item
              index1
              index2
              iostat
              log
              metric
              mix
              new_order
              oprofile
              order_line
              orders
              pkcustomer
              pkdistrict
              pkitem
              pknew_order
              pkorder_line
              pkorders
              pkstock
              pkwarehouse
              rampup
              readprofile
              rt_d
              rt_n
              rt_o
              rt_p
              rt_s
              sample_length
              sar
              scale_factor
              start_time
              stock
              sysctl
              vmstat
              warehouse
              );

use vars qw( %FIELDS $AUTOLOAD $VERSION );
our $VERSION = '1.4';

=head2 new()

Creates a new Test::Parser::Dbt2 instance.
Also calls the Test::Parser base class' new() routine.
Takes no arguments.

=cut

sub new {
    my $class = shift;
    my Test::Parser::Dbt2 $self = fields::new($class);
    $self->SUPER::new();

    $self->name('dbt2');
    $self->type('standards');

    $self->{cmdline} = '';
    $self->{data} = {};
    $self->{db} = undef;
    $self->{duration} = 0;
    $self->{errors} = 0;
    $self->{format} = 'png';
    $self->{iostat} = undef;
    $self->{metric} = 0;
    $self->{mix} = [];
    $self->{oprofile} = undef;
    $self->{rampup} = 0;
    $self->{readprofile} = undef;
    $self->{sample_length} = 60; # Seconds.
    $self->{sar} = undef;
    $self->{scale_factor} = 0;
    $self->{start_time} = undef;
    $self->{sysctl} = undef;
    $self->{vmstat} = undef;
    #
    # Transaction distribution data.
    #
    $self->{dist_d} = ();
    $self->{dist_n} = ();
    $self->{dist_o} = ();
    $self->{dist_p} = ();
    $self->{dist_s} = ();
    #
    # Transaction response time data.
    #
    $self->{rt_d} = ();
    $self->{rt_n} = ();
    $self->{rt_o} = ();
    $self->{rt_p} = ();
    $self->{rt_s} = ();
    #
    # Hash of devices to plot for iostat per tablespace.
    #
    $self->{customer} = undef;
    $self->{district} = undef;
    $self->{history} = undef;
    $self->{item} = undef;
    $self->{index1} = undef;
    $self->{index2} = undef;
    $self->{log} = undef;
    $self->{new_order} = undef;
    $self->{order_line} = undef;
    $self->{orders} = undef;
    $self->{pkcustomer} = undef;
    $self->{pkdistrict} = undef;
    $self->{pkitem} = undef;
    $self->{pknew_order} = undef;
    $self->{pkorders} = undef;
    $self->{pkorder_line} = undef;
    $self->{pkstock} = undef;
    $self->{pkwarehouse} = undef;
    $self->{stock} = undef;
    $self->{warehouse} = undef;

    return $self;
}

=head3 data()

Returns a hash representation of the dbt2 data.

=cut
sub data {
    my $self = shift;
    if (@_) {
        $self->{data} = @_;
    }
    return {dbt2 => {$self->{data}}};
}

=head3

Override of Test::Parser's default parse() routine to make it able
to parse dbt2 output.  Support only reading from a file until a better
parsing algorithm comes along.

=cut
sub parse {
    #
    # TODO
    # Make this handle GLOBS and stuff like the parent class.
    #
    my $self = shift;
    my $input = shift or return undef;
    return undef unless (-d $input);
    my $filename;
    #
    # Put everything into a report directory under the specified DBT-2 output
    # directory.
    #
    $self->{outdir} = $input;
    my $report_dir = "$input/report";
    system "mkdir -p $report_dir";
    #
    # Get general test information.
    #
    $filename = "$input/readme.txt";
    if (-f $filename) {
        $self->parse_readme($filename);
    }
    #
    # Get the mix data.
    #
    $filename = "$input/driver/mix.log";
    if (-f $filename) {
        $self->parse_mix($filename);
    }
    #
    # Get database data.  First determine what database was used.
    #
    $filename = "$input/db/readme.txt";
    if (-f $filename) {
        $self->parse_db($filename);
    }
    #
    # Put all the iostat plots under a iostat directory.
    #
    my $iostat = "$input/iostatx.out";
    my $iostat_dir = "$report_dir/iostat";
    if (-f $iostat) {
        system "mkdir -p $iostat_dir";
        $self->{iostat} = new Test::Parser::Iostat;
        $self->{iostat}->outdir($iostat_dir);
        $self->{iostat}->parse($iostat);
        my $d = $self->{iostat}->data();
        for my $k (keys %$d) {
            $self->{data}->{$k} = $d->{$k};
        }
    }
    #
    # Get oprofile data.
    #
    my $oprofile = "$input/oprofile.txt";
    if (-f $oprofile) {
        $self->{oprofile} = new Test::Parser::Oprofile;
        $self->{oprofile}->parse($oprofile);
        my $d = $self->{oprofile}->data();
        for my $k (keys %$d) {
            $self->{data}->{$k} = $d->{$k};
        }
    }
    #
    # Get readprofile data.
    #
    my $readprofile = "$input/readprofile.txt";
    if (-f $readprofile) {
        $self->{readprofile} = new Test::Parser::Readprofile;
        $self->{readprofile}->parse($readprofile);
        my $d = $self->{readprofile}->data();
        for my $k (keys %$d) {
            $self->{data}->{$k} = $d->{$k};
        }
    }
    #
    # Get sysctl data.
    #
    my $sysctl = "$input/proc.out";
    if (-f $sysctl) {
        $self->{sysctl} = new Test::Parser::Sysctl;
        $self->{sysctl}->parse($sysctl);
        my $d = $self->{sysctl}->data();
        for my $k (keys %$d) {
            $self->{data}->{os}->{$k} = [$d->{$k}];
        }
    }
    #
    # Put all the sar plots under a sar directory.
    #
    my $sar = "$input/sar.out";
    my $sar_dir = "$report_dir/sar";
    if (-f $sar) {
        system "mkdir -p $sar_dir";
        $self->{sar} = new Test::Parser::Sar;
        $self->{sar}->outdir($sar_dir);
        $self->{sar}->parse($sar);
        my $d = $self->{sar}->data();
        for my $k (keys %{$d->{sar}}) {
            $self->{data}->{sar}->{$k} = [$d->{sar}->{$k}];
        }
    }
    #
    # Put all the vmstat plots under a vmstat directory.
    #
    my $vmstat = "$input/vmstat.out";
    my $vmstat_dir = "$report_dir/vmstat";
    if (-f $vmstat) {
        system "mkdir -p $vmstat_dir";
        $self->{vmstat} = new Test::Parser::Vmstat;
        $self->{vmstat}->outdir($vmstat_dir);
        $self->{vmstat}->parse($vmstat);
        my $d = $self->{vmstat}->data();
        for my $k (keys %$d) {
            $self->{data}->{$k} = $d->{$k};
        }
    }

    return 1;
}

sub parse_db {
    my $self = shift;
    my $filename = shift;

    open(FILE, "< $filename");
    my $line = <FILE>;
    close(FILE);
    #
    # Check to see if the parameter output file exists.
    #
    $filename = $self->{outdir} . "/db/param.out";
    if (-f $filename) {
        if ($line =~ /PostgreSQL/) {
            $self->{db} = new Test::Parser::PgOptions;
        }
        $self->{db}->parse($filename);
        my $d = $self->{db}->data();
        for my $k (keys %$d) {
            $self->{data}->{db}->{$k} = $d->{$k};
        }
    }
}

sub parse_mix {
    my $self = shift;
    my $filename = shift;

    my $current_time;
    my %current_transaction_count;
    my %error_count;
    my $previous_time;
    my %rollback_count;
    my $steady_state_start_time = 0;
    my $total_transaction_count = 0;
    my %transaction_count;
    my %transaction_response_time;

    my @delivery_response_time = ();
    my @new_order_response_time = ();
    my @order_status_response_time = ();
    my @payement_response_time = ();
    my @stock_level_response_time = ();

    #
    # Zero out the data.
    #
    $current_transaction_count{ 'd' } = 0;
    $current_transaction_count{ 'n' } = 0;
    $current_transaction_count{ 'o' } = 0;
    $current_transaction_count{ 'p' } = 0;
    $current_transaction_count{ 's' } = 0;

    $rollback_count{ 'd' } = 0;
    $rollback_count{ 'n' } = 0;
    $rollback_count{ 'o' } = 0;
    $rollback_count{ 'p' } = 0;
    $rollback_count{ 's' } = 0;
    #
    # Transaction counts for the steady state portion of the test.
    #
    $transaction_count{ 'd' } = 0;
    $transaction_count{ 'n' } = 0;
    $transaction_count{ 'o' } = 0;
    $transaction_count{ 'p' } = 0;
    $transaction_count{ 's' } = 0;

    push @{$self->{mix}},
            {elapsed_time => 0, d => 0, n => 0, o => 0, p=> 0, s=> 0};

    #
    # Because of the way the math works out, and because we want to have 0's for
    # the first datapoint, this needs to start at the first $sample_length,
    # which is in minutes.
    #
    my $elapsed_time = 1;

    open(FILE, "< $filename");
    while (defined(my $line = <FILE>)) {
        chomp $line;
        my @word = split /,/, $line;

        if (scalar(@word) == 4) {
            #
            # Count transactions per second based on transaction type.
            #
            $current_time = $word[0];
            my $response_time = $word[2];
            unless ($self->{start_time}) {
                $self->{start_time} = $previous_time = $current_time;
            }
            #
            # Normalize the data over the specified sample length.
            #
            if ($current_time >= ($previous_time + $self->{sample_length})) {
                push @{$self->{mix}},
                        {elapsed_time => $elapsed_time,
                        d => $current_transaction_count{'d'},
                        n => $current_transaction_count{'n'},
                        o => $current_transaction_count{'o'},
                        p => $current_transaction_count{'p'},
                        s => $current_transaction_count{'s'}};
                ++$elapsed_time;
                $previous_time = $current_time;
                #
                # Reset counters for the next sample interval.
                #
                $current_transaction_count{'d'} = 0;
                $current_transaction_count{'n'} = 0;
                $current_transaction_count{'o'} = 0;
                $current_transaction_count{'p'} = 0;
                $current_transaction_count{'s'} = 0;
            }
            #
            # Determine response time distributions for each transaction
            # type.  Also determine response time for a transaction when
            # it occurs during the run.  Calculate response times for
            # each transaction.
            #
            my $time;
            $time = sprintf("%.2f", $response_time);
            my $x_time = ($word[ 0 ] - $self->{start_time}) / 60;
            if ($word[1] eq 'd') {
                unless ($steady_state_start_time == 0) {
                    ++$transaction_count{'d'};
                    $transaction_response_time{'d'} += $response_time;
                    push @delivery_response_time, $response_time;
                    ++$current_transaction_count{'d'};
                }
                ++$self->{dist_d}->{$time};
                push @{$self->{rt_d}}, {elapsed_time => $x_time,
                        response_time => $response_time};
            } elsif ($word[1] eq 'n') {
                unless ($steady_state_start_time == 0) {
                    ++$transaction_count{'n'};
                    $transaction_response_time{'n'} += $response_time;
                    push @new_order_response_time, $response_time;
                    ++$current_transaction_count{'n'};
                }
                ++$self->{dist_n}->{$time};
                push @{$self->{rt_n}}, {elapsed_time => $x_time,
                        response_time => $response_time};
            } elsif ($word[1] eq 'o') {
                unless ($steady_state_start_time == 0) {
                    ++$transaction_count{'o'};
                    $transaction_response_time{'o'} += $response_time;
                    push @order_status_response_time, $response_time;
                    ++$current_transaction_count{'o'};
                }
                ++$self->{dist_o}->{$time};
                push @{$self->{rt_o}}, {elapsed_time => $x_time,
                        response_time => $response_time};
            } elsif ($word[1] eq 'p') {
                unless ($steady_state_start_time == 0) {
                    ++$transaction_count{'p'};
                    $transaction_response_time{'p'} += $response_time;
                    push @payement_response_time, $response_time;
                    ++$current_transaction_count{'p'};
                }
                ++$self->{dist_p}->{$time};
                push @{$self->{rt_p}}, {elapsed_time => $x_time,
                        response_time => $response_time};
            } elsif ($word[1] eq 's') {
                unless ($steady_state_start_time == 0) {
                    ++$transaction_count{'s'};
                    $transaction_response_time{'s'} += $response_time;
                    push @stock_level_response_time, $response_time;
                    ++$current_transaction_count{'s'};
                }
                ++$self->{dist_s}->{$time};
                push @{$self->{rt_s}}, {elapsed_time => $x_time,
                        response_time => $response_time};
            } elsif ($word[1] eq 'D') {
                ++$rollback_count{'d'} unless ($steady_state_start_time == 0);
            } elsif ($word[1] eq 'N') {
                ++$rollback_count{'n'} unless ($steady_state_start_time == 0);
            } elsif ($word[1] eq 'O') {
                ++$rollback_count{'o'} unless ($steady_state_start_time == 0);
            } elsif ($word[1] eq 'P') {
                ++$rollback_count{'p'} unless ($steady_state_start_time == 0);
            } elsif ($word[1] eq 'S') {
                ++$rollback_count{'s'} unless ($steady_state_start_time == 0);
            } elsif ($word[1] eq 'E') {
                ++$self->{errors};
                ++$error_count{$word[3]};
            }
            ++$total_transaction_count;
        } elsif (scalar(@word) == 2) {
            #
            # Look for that 'START' marker to determine the end of the rampup
            # time and to calculate the average throughput from that point to
            # the end of the test.
            #
            $steady_state_start_time = $word[0];
        }
    }
    close(FILE);
    #
    # Calculated the number of New Order transactions per second.
    #
    my $tps = $transaction_count{'n'} / ($current_time - $self->{start_time});
    $self->{metric} = $tps * 60.0;
    $self->{data}->{metric} = $self->{metric};
    $self->{duration} = ($current_time - $self->{start_time}) / 60.0;
    $self->{rampup} = ($steady_state_start_time - $self->{start_time}) / 60.0;
    #
    # Other transaction statistics.
    #
    my %transaction;
    $transaction{'d'} = "Delivery";
    $transaction{'n'} = "New Order";
    $transaction{'o'} = "Order Status";
    $transaction{'p'} = "Payment";
    $transaction{'s'} = "Stock Level";
    #
    # Get the index for the 90th percentile response time index for each
    # transaction.
    #
    my $delivery90index = $transaction_count{'d'} * 0.90;
    my $new_order90index = $transaction_count{'n'} * 0.90;
    my $order_status90index = $transaction_count{'o'} * 0.90;
    my $payment90index = $transaction_count{'p'} * 0.90;
    my $stock_level90index = $transaction_count{'s'} * 0.90;

    my %response90th;

    my $floor;
    my $ceil;
    #
    # 90th percentile for Delivery transactions.
    #
    $floor = floor($delivery90index);
    $ceil = ceil($delivery90index);
    if ($floor == $ceil) {
        $response90th{'d'} = $delivery_response_time[$delivery90index];
    } else {
        $response90th{'d'} = ($delivery_response_time[$floor] +
                $delivery_response_time[$ceil]) / 2;
    }
    #
    # 90th percentile for New Order transactions.
    #
    $floor = floor($new_order90index);
    $ceil = ceil($new_order90index);
    if ($floor == $ceil) {
        $response90th{'n'} = $new_order_response_time[$new_order90index];
    } else {
        $response90th{'n'} = ($new_order_response_time[$floor] +
                $new_order_response_time[$ceil]) / 2;
    }
    #
    # 90th percentile for Order Status transactions.
    #
    $floor = floor($order_status90index);
    $ceil = ceil($order_status90index);
    if ($floor == $ceil) {
        $response90th{'o'} = $order_status_response_time[$order_status90index];
    } else {
        $response90th{'o'} = ($order_status_response_time[$floor] +
                $order_status_response_time[$ceil]) / 2;
    }
    #
    # 90th percentile for Payment transactions.
    #
    $floor = floor($payment90index);
    $ceil = ceil($payment90index);
    if ($floor == $ceil) {
        $response90th{'p'} = $payement_response_time[$payment90index];
    } else {
        $response90th{'p'} = ($payement_response_time[$floor] +
                $payement_response_time[$ceil]) / 2;
    }
    #
    # 90th percentile for Stock Level transactions.
    #
    $floor = floor($stock_level90index);
    $ceil = ceil($stock_level90index);
    if ($floor == $ceil) {
        $response90th{'s'} = $stock_level_response_time[$stock_level90index];
    } else {
        $response90th{'s'} = ($stock_level_response_time[$floor] +
                $stock_level_response_time[$ceil]) / 2;
    }
    #
    # Summarize the transaction statistics into the hash structure for XML.
    #
    $self->{data}->{transactions}->{transaction} = ();
    foreach my $idx ('d', 'n', 'o', 'p', 's') {
        my $mix = ($transaction_count{$idx} + $rollback_count{$idx}) /
                $total_transaction_count * 100.0;
        my $rt_avg = 0;
        if ($transaction_count{$idx} != 0) {
            $rt_avg = $transaction_response_time{$idx} /
                    $transaction_count{$idx};
        }
        my $txn_total = $transaction_count{$idx} + $rollback_count{$idx};
        my $rollback_per = $rollback_count{$idx} / $txn_total * 100.0;
        push @{$self->{data}->{transactions}->{transaction}},
                {mix => $mix,
                rt_avg => $rt_avg,
                rt_90th => $response90th{$idx},
                total => $txn_total,
                rollbacks => $rollback_count{$idx},
                rollback_per => $rollback_per,
                name => $transaction{$idx}};
    }
}

sub parse_readme {
    my $self = shift;
    my $filename = shift;

    open(FILE, "< $filename");
    my $line = <FILE>;
    chomp($line);
    $self->{data}->{date} = $line;

    $line = <FILE>;
    chomp($line);
    $self->{data}->{comment} = [$line];

    $line = <FILE>;
    my @i = split / /, $line;
    $self->{data}->{os}{name} = $i[0];
    $self->{data}->{os}{version} = $i[2];

	$self->{cmdline} = <FILE>;

	$line = <FILE>;
	my @data = split /:/, $line;
    $data[1] =~ s/^\s+//;
	@data = split / /, $data[1];
    $self->{scale_factor} = $data[0];

    close(FILE);
}

=head3 plot()

Plot the data using Gnuplot.

=cut
sub plot {
    my $self = shift;
    my $format = shift;

    my $previous_format = $self->{format};
    $self->{format} = $format if ($format);
    #
    # Plot transaction distributions.
    #
    $self->plot_distributions();
    #
    # Plot all transactions.
    #
    $self->plot_transactions();
    #
    # Plot all transaction response time distributions.
    #
    $self->plot_response_times();
    #
    # Plot other data.
    #
    if ($self->{vmstat}) {
        $self->{vmstat}->format($self->{format});
        $self->{vmstat}->plot();
        $self->{vmstat}->format($previous_format);
    }
    if ($self->{sar}) {
        $self->{sar}->format($self->{format});
        $self->{sar}->plot();
        $self->{sar}->format($previous_format);
    }
    if ($self->{iostat}) {
        $self->{iostat}->format($self->{format});
        $self->{iostat}->plot();
        my $old_outdir = $self->{iostat}->outdir();
        #
        # Customer tablespace devices.
        #
        if ($self->{customer}) {
            $self->{iostat}->outdir("$old_outdir/customer");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{customer}});
        }
        #
        # District tablespace devices.
        #
        if ($self->{district}) {
            $self->{iostat}->outdir("$old_outdir/district");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{district}});
        }
        #
        # History tablespace devices.
        #
        if ($self->{history}) {
            $self->{iostat}->outdir("$old_outdir/history");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{history}});
        }
        #
        # Item tablespace devices.
        #
        if ($self->{item}) {
            $self->{iostat}->outdir("$old_outdir/item");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{item}});
        }
        #
        # Index1 tablespace devices.
        #
        if ($self->{index1}) {
            $self->{iostat}->outdir("$old_outdir/index1");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{index1}});
        }
        #
        # Index2 tablespace devices.
        #
        if ($self->{index2}) {
            $self->{iostat}->outdir("$old_outdir/index2");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{index2}});
        }
        #
        # Log tablespace devices.
        #
        if ($self->{log}) {
            $self->{iostat}->outdir("$old_outdir/log");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{log}});
        }
        #
        # New Order tablespace devices.
        #
        if ($self->{new_order}) {
            $self->{iostat}->outdir("$old_outdir/new_order");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{new_order}});
        }
        #
        # Orders tablespace devices.
        #
        if ($self->{orders}) {
            $self->{iostat}->outdir("$old_outdir/orders");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{orders}});
        }
        #
        # Order Line tablespace devices.
        #
        if ($self->{order_line}) {
            $self->{iostat}->outdir("$old_outdir/order_line");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{order_line}});
        }
        #
        # Customer primary key tablespace devices.
        #
        if ($self->{pkcustomer}) {
            $self->{iostat}->outdir("$old_outdir/pkcustomer");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{pkcustomer}});
        }
        #
        # District primary key tablespace devices.
        #
        if ($self->{pkdistrict}) {
            $self->{iostat}->outdir("$old_outdir/pkdistrict");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{pkdistrict}});
        }
        #
        # Item primary key tablespace devices.
        #
        if ($self->{pkitem}) {
            $self->{iostat}->outdir("$old_outdir/pkitem");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{pkitem}});
        }
        #
        # New Order primary key tablespace devices.
        #
        if ($self->{pknew_order}) {
            $self->{iostat}->outdir("$old_outdir/pknew_order");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{pknew_order}});
        }
        #
        # Order Line primary key tablespace devices.
        #
        if ($self->{pkorder_line}) {
            $self->{iostat}->outdir("$old_outdir/pkorder_line");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{pkorder_line}});
        }
        #
        # Orders primary key tablespace devices.
        #
        if ($self->{pkorders}) {
            $self->{iostat}->outdir("$old_outdir/pkorders");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{pkorders}});
        }
        #
        # Stock primary key tablespace devices.
        #
        if ($self->{pkstock}) {
            $self->{iostat}->outdir("$old_outdir/pkstock");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{pkstock}});
        }
        #
        # Warehouse primary key tablespace devices.
        #
        if ($self->{pkwarehouse}) {
            $self->{iostat}->outdir("$old_outdir/pkwarehouse");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{pkwarehouse}});
        }
        #
        # Stock tablespace devices.
        #
        if ($self->{stock}) {
            $self->{iostat}->outdir("$old_outdir/stock");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{stock}});
        }
        #
        # Warehouse tablespace devices.
        #
        if ($self->{warehouse}) {
            $self->{iostat}->outdir("$old_outdir/warehouse");
            system "mkdir -p " . $self->{iostat}->outdir();
            $self->{iostat}->plot(@{$self->{warehouse}});
        }
        $self->{iostat}->outdir("$old_outdir");
        $self->{iostat}->format($previous_format);
    }
}

sub plot_distributions {
    my $self = shift;

    my @x;
    my @y;
    my @t = ("Delivery", "New Order", "Order Status", "Payment", "Stock Level");
    my @f = ("dist_d", "dist_n", "dist_o", "dist_p", "dist_s");

    for (my $i = 0; $i < 5; $i++) {
        @x = ();
        @y = ();
        my %gopts = (
                'title' => "$t[$i] Transaction Response Time Distribution",
                'yrange' => '[0:]',
                'x-axis label' => 'Response Time (Seconds)',
                'y-axis label' => 'Number of Transactions',
                'extra_opts' => 'set grid xtics ytics',
                'output type' => $self->{format},
                'output file' => "$self->{outdir}/report/$f[$i].$self->{format}"
        );
        my %dsopts = (
                'title' => $t[$i],
                'type' => 'columns',
        );
        foreach my $x2 (sort keys %{$self->{$f[$i]}}) {
            push @x, $x2;
            push @y, $self->{$f[$i]}->{$x2};
        }
        gnuplot(\%gopts, [\%dsopts, \@x, \@y]);
    }
}

sub plot_response_times {
    my $self = shift;

    my @x;
    my @y;
    my @t = ("Delivery", "New Order", "Order Status", "Payment", "Stock Level");
    my @f = ("rt_d", "rt_n", "rt_o", "rt_p", "rt_s");

    for (my $i = 0; $i < 5; $i++) {
        @x = ();
        @y = ();
        my %gopts = (
                'title' => "$t[$i] Transaction Response Time",
                'yrange' => '[0:]',
                'x-axis label' => "Elapsed Time (Minutes)",
                'y-axis label' => 'Response Time (Seconds)',
                'extra_opts' => 'set grid xtics ytics',
                'output type' => $self->{format},
                'output file' => "$self->{outdir}/report/$f[$i].$self->{format}"
        );
        my %dsopts = (
                'style' => 'lines',
                'title' => $t[$i],
                'type' => 'columns',
        );
        for my $j (@{$self->{$f[$i]}}) {
            push @x, $j->{elapsed_time};
            push @y, $j->{response_time};
        }
        gnuplot(\%gopts, [\%dsopts, \@x, \@y]);
    }
}

sub plot_transactions {
    my $self = shift;

    my @x = ();
    my @d = ();
    my @n = ();
    my @o = ();
    my @p = ();
    my @s = ();

    my %gopts_d = (
            'title' => 'Delivery Transactions',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time (Minutes)",
            'y-axis label' => 'Transactions per Minute',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/report/dtpm.$self->{format}"
    );
    my %dsopts_d = (
            'style' => 'lines',
            'title' => 'Delivery',
            'type' => 'columns',
    );

    my %gopts_no = (
            'title' => 'New Order Transactions',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time (Minutes)",
            'y-axis label' => 'Transactions per Minute',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/report/notpm.$self->{format}"
    );
    my %dsopts_no = (
            'style' => 'lines',
            'title' => 'New Order',
            'type' => 'columns',
    );

    my %gopts_o = (
            'title' => 'Order Status Transactions',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time (Minutes)",
            'y-axis label' => 'Transactions per Minute',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/report/ostpm.$self->{format}"
    );

    my %dsopts_o = (
            'style' => 'lines',
            'title' => 'Order Status',
            'type' => 'columns',
    );
    my %gopts_p = (
            'title' => 'Payment Transactions',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time (Minutes)",
            'y-axis label' => 'Transactions per Minute',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/report/ptpm.$self->{format}"
    );
    my %dsopts_p = (
            'style' => 'lines',
            'title' => 'Payment',
            'type' => 'columns',
    );

    my %gopts_s = (
            'title' => 'Stock Level Transactions',
            'yrange' => '[0:]',
            'x-axis label' => "Elapsed Time (Minutes)",
            'y-axis label' => 'Transactions per Minute',
            'extra_opts' => 'set grid xtics ytics',
            'output type' => $self->{format},
            'output file' => "$self->{outdir}/report/sltpm.$self->{format}"
    );
    my %dsopts_s = (
            'style' => 'lines',
            'title' => 'Stock Level',
            'type' => 'columns',
    );

    for my $i (@{$self->{mix}}) {
        push @x, $i->{elapsed_time};
        push @d, $i->{d};
        push @n, $i->{n};
        push @o, $i->{o};
        push @p, $i->{p};
        push @s, $i->{s};
    }

    gnuplot(\%gopts_d, [\%dsopts_d, \@x, \@d]);
    gnuplot(\%gopts_no, [\%dsopts_no, \@x, \@n]);
    gnuplot(\%gopts_o, [\%dsopts_o, \@x, \@o]);
    gnuplot(\%gopts_p, [\%dsopts_p, \@x, \@p]);
    gnuplot(\%gopts_s, [\%dsopts_s, \@x, \@s]);
}

=head3 customer_devices()

Set the customer devices.

=cut
sub customer_devices {
    my $self = shift;
    if (@_) {
        @{$self->{customer}} = @_;
    }
    return @{$self->{customer}};
}

=head3 district_devices()

Set the district devices.

=cut
sub district_devices {
    my $self = shift;
    if (@_) {
        @{$self->{district}} = @_;
    }
    return @{$self->{district}};
}

=head3 history_devices()

Set the history devices.

=cut
sub history_devices {
    my $self = shift;
    if (@_) {
        @{$self->{history}} = @_;
    }
    return @{$self->{history}};
}

=head3 item_devices()

Set the item devices.

=cut
sub item_devices {
    my $self = shift;
    if (@_) {
        @{$self->{item}} = @_;
    }
    return @{$self->{item}};
}

=head3 index1_devices()

Set the index1 devices.

=cut
sub index1_devices {
    my $self = shift;
    if (@_) {
        @{$self->{index1}} = @_;
    }
    return @{$self->{index1}};
}

=head3 index2_devices()

Set the index2 devices.

=cut
sub index2_devices {
    my $self = shift;
    if (@_) {
        @{$self->{index2}} = @_;
    }
    return @{$self->{index2}};
}

=head3 log_devices()

Set the log devices.

=cut
sub log_devices {
    my $self = shift;
    if (@_) {
        @{$self->{log}} = @_;
    }
    return @{$self->{log}};
}

=head3 new_order_devices()

Set the new_order devices.

=cut
sub new_order_devices {
    my $self = shift;
    if (@_) {
        @{$self->{new_order}} = @_;
    }
    return @{$self->{new_order}};
}

=head3 order_line_devices()

Set the order_line devices.

=cut
sub order_line_devices {
    my $self = shift;
    if (@_) {
        @{$self->{order_line}} = @_;
    }
    return @{$self->{order_line}};
}

=head3 orders_devices()

Set the orders devices.

=cut
sub orders_devices {
    my $self = shift;
    if (@_) {
        @{$self->{orders}} = @_;
    }
    return @{$self->{orders}};
}

=head3 pkcustomer_devices()

Set the customer primary key tablespace devices.

=cut
sub pkcustomer_devices {
    my $self = shift;
    if (@_) {
        @{$self->{pkcustomer}} = @_;
    }
    return @{$self->{pkcustomer}};
}

=head3 pkdistrict_devices()

Set the district primary key tablespace devices.

=cut
sub pkdistrict_devices {
    my $self = shift;
    if (@_) {
        @{$self->{pkdistrict}} = @_;
    }
    return @{$self->{pkdistrict}};
}

=head3 pkitem_devices()

Set the item primary key tablespace devices.

=cut
sub pkitem_devices {
    my $self = shift;
    if (@_) {
        @{$self->{pkitem}} = @_;
    }
    return @{$self->{pkitem}};
}

=head3 pknew_order_devices()

Set the new_order primary key tablespace devices.

=cut
sub pknew_order_devices {
    my $self = shift;
    if (@_) {
        @{$self->{pknew_order}} = @_;
    }
    return @{$self->{pknew_order}};
}

=head3 pkorder_line_devices()

Set the order_line primary key tablespace devices.

=cut
sub pkorder_line_devices {
    my $self = shift;
    if (@_) {
        @{$self->{pkorder_line}} = @_;
    }
    return @{$self->{pkorder_line}};
}

=head3 pkorders_devices()

Set the orders primary key tablespace devices.

=cut
sub pkorders_devices {
    my $self = shift;
    if (@_) {
        @{$self->{pkorders}} = @_;
    }
    return @{$self->{pkorders}};
}

=head3 pkstock_devices()

Set the stock devices.

=cut
sub pkstock_devices {
    my $self = shift;
    if (@_) {
        @{$self->{pkstock}} = @_;
    }
    return @{$self->{pkstock}};
}

=head3 pkwarehouse_devices()

Set the warehouse primary key tablespace devices.

=cut
sub pkwarehouse_devices {
    my $self = shift;
    if (@_) {
        @{$self->{pkwarehouse}} = @_;
    }
    return @{$self->{pkwarehouse}};
}

=head3 stock_devices()

Set the stock devices.

=cut
sub stock_devices {
    my $self = shift;
    if (@_) {
        @{$self->{stock}} = @_;
    }
    return @{$self->{stock}};
}

=head3 warehouse_devices()

Set the warehouse devices.

=cut
sub warehouse_devices {
    my $self = shift;
    if (@_) {
        @{$self->{warehouse}} = @_;
    }
    return @{$self->{warehouse}};
}

=head3 to_html()

Create HTML pages.

=cut
sub to_html {
    my $self = shift;

    my $filename;
    my $links = '';

    my $q = new CGI;
    my $h = $q->start_html('Database Test 2 Report');

    $h .= $q->h1('Database Test 2 Report');
    $h .= $q->p($self->{data}->{date});
    $filename = "$self->{outdir}/report/result.xml";
    if (-f $filename) {
        $h .= $q->p( 'Download all results data in ' .
                $q->a({href => 'result.xml'}, 'xml') . ' format.');
    }
    $filename = "$self->{outdir}/report/notpm.png";
    if (-f $filename) {
        $links .= ' [' . $q->a({href => 'notpm.png'}, 'png') . ']';
    }
    $filename = "$self->{outdir}/report/notpm.svg";
    if (-f $filename) {
        $links .= ' [' . $q->a({href => 'notpm.svg'}, 'svg') . ']';
    }
    $h .= $q->p(
            $q->table(
                    $q->caption('Results Summary') .
                    $q->Tr(
                            $q->td({align => 'right'},
                                    'New Order Transactions per Minute (notpm):') .
                            $q->td({align => 'right'},
                                    sprintf('%.2f', $self->{metric}) . $links)
                    ) .
                    $q->Tr(
                            $q->td({align => 'right'}, 'Scale Factor:') .
                            $q->td($self->{scale_factor})
                    ) .
                    $q->Tr(
                            $q->td({align => 'right'},
                                    'Test Duration (min.):') .
                            $q->td(sprintf('%.2f', $self->{duration}))
                    ) .
                    $q->Tr(
                            $q->td({align => 'right'}, 'Ramp-up Time (min.):') .
                            $q->td(sprintf('%.2f', $self->{rampup}))
                    ) .
                    $q->Tr(
                            $q->td({align => 'right'},
                                    'Total Unknown Errors:') .
                            $q->td($self->{errors})
                    )
            )
    );
    my $s = '';
    for my $i (@{$self->{data}->{transactions}->{transaction}}) {
        my $links = '';
        my $txn = '';
        if ($i->{name} eq 'Delivery') {
            $txn = 'd';
        } elsif ($i->{name} eq 'New Order') {
            $txn = 'n';
        } elsif ($i->{name} eq 'Order Status') {
            $txn = 'o';
        } elsif ($i->{name} eq 'Payment') {
            $txn = 'p';
        } elsif ($i->{name} eq 'Stock Level') {
            $txn = 's';
        }
        #
        # Add links to a transaction's response time charts.
        #
        $links .= $q->td($self->image_check("rt_$txn.png") .
                $self->image_check("rt_$txn.svg"));
        #
        # Add links to a transaction's time distribution charts.
        #
        $links .= $q->td($self->image_check("dist_$txn.png") .
                $self->image_check("dist_$txn.svg"));

        $s .= $q->Tr(
                $q->td($i->{name}) .
                $q->td({align => "right"}, sprintf('%.2f', $i->{mix})) .
                $q->td({align => "right"}, $i->{total}) .
                $q->td({align => "right"}, sprintf('%.2f', $i->{rt_avg})) .
                $q->td({align => "right"}, sprintf('%.2f', $i->{rt_90th})) .
                $q->td({align => "right"}, $i->{rollbacks}) .
                $q->td({align => "right"}, sprintf('%.2f', $i->{rollback_per})) .
                $links
        );
    }
    $h .= $q->p(
            $q->table({border => 1},
                    $q->caption('Transaction Summary') .
                    $q->Tr(
                            $q->th({colspan => 3}, 'Transaction') .
                            $q->th({colspan => 2}, 'Response Time') .
                            $q->th({colspan => 2}, 'Rollbacks') .
                            $q->th({colspan => 2}, 'Charts')
                    ) .
                    $q->Tr(
                            $q->th('Name') .
                            $q->th('Mix %') .
                            $q->th('Total') .
                            $q->th('Average (s)') .
                            $q->th('90th %') .
                            $q->th('Total') .
                            $q->th('%') .
                            $q->th('Response Time') .
                            $q->th('Time Distribution')
                    ) .
                    $s
            )
    );
    $h .= $q->p(
            $q->table(
                    $q->caption('System Summary') .
                    $q->Tr(
                            $q->td({align => 'right'}, 'Operating System:') .
                            $q->td($self->{data}->{os}{name} . ' ' .
                                    $self->{data}->{os}{version}) .
                            $q->td($q->a({href => '../proc.out'}, 'Settings'))
                    ) .
                    $q->Tr(
                            $q->td({align => 'right'}, 'Database:') .
                            $q->td($self->{data}->{db}->{database}{name} . ' ' .
                                    $self->{data}->{db}->{database}{version}) .
                            $q->td($q->a({href => '../db/param.out'},
                                    'Settings')) .
                            $q->td($q->a({href => '../db/'},
                                    'Raw Data'))
                    )
            )
    );
    $h .= $q->p($q->b('Comment: ') . $self->{data}->{comment}[0]);
    $h .= $q->p($q->b('Command line: ') . $self->{cmdline});
    $h .= $q->h2('Profiles');
    $links = '';
    if (-f "$self->{outdir}/readprofile_ticks.txt") {
        $links .= $q->a({href => '../readprofile_ticks.txt'}, 'Readprofile') .
                $q->br;
    }
    if (-f "$self->{outdir}/oprofile.txt") {
        $links .= $q->a({href => '../oprofile.txt'}, 'Oprofile') .
                $q->br;
    }
    if (-f "$self->{outdir}/callgraph.txt") {
        $links .= $q->a({href => '../callgraph.txt'}, 'Oprofile Callgraph') .
                $q->br;
    }
    if (-f "$self->{outdir}/oprofile/assembly.txt") {
        $links .= $q->a({href => '../oprofile/assembly.txt'},
                'Oprofile Annotated Assembly') . $q->br;
    }
    $h .= $q->p($links);
    $h .= $q->h2('System Statistics');
    if (-d "$self->{outdir}/report/sar") {
        $h .= $q->h3('sar [' . $q->a({href => '../sar.out'}, 'Raw Data') . ']');
        $h .= $q->p(
                $q->ul(
                        $q->li('Processor Utilization per CPU' .
                                $self->image_check('sar/sar-cpu.png') .
                                $self->image_check('sar/sar-cpu.svg')) .
                        $q->li('Context Switches' .
                                $self->image_check('sar/sar-cswch_s.png') .
                                $self->image_check('sar/sar-cswch_s.svg')) .
                        $q->li('Unused Directory Cache Entries' .
                                $self->image_check('sar/sar-dentunusd.png') .
                                $self->image_check('sar/sar-dentunusd.svg')) .
                        $q->li('Allocated Disk Quota Entries' .
                                $self->image_check('sar/sar-dquot-sz.png') .
                                $self->image_check('sar/sar-dquot-sz.svg')) .
                        $q->li('File Handles' .
                                $self->image_check('sar/sar-file-sz.png') .
                                $self->image_check('sar/sar-file-sz.svg')) .
                        $q->li('Inode Handles' .
                                $self->image_check('sar/sar-inode-sz.png') .
                                $self->image_check('sar/sar-inode-sz.svg')) .
                        $q->li('Inode %' .
                                $self->image_check('sar/sar-inode-p.png') .
                                $self->image_check('sar/sar-inode-p.svg')) .
                        $q->li('Individual Interrupt Counts per Processor' .
                                $self->image_check('sar/sar-intr.png') .
                                $self->image_check('sar/sar-intr.svg')) .
                        $q->li('Aggregate Interrupt Counts' .
                                $self->image_check('sar/sar-intr_s.png') .
                                $self->image_check('sar/sar-intr_s.svg')) .
                        $q->li('Memory' .
                                $self->image_check('sar/sar-memory.png') .
                                $self->image_check('sar/sar-memory.svg')) .
                        $q->li('Memory Usage' .
                                $self->image_check('sar/sar-memory-usage.png') .
                                $self->image_check(
                                        'sar/sar-memory-usage.svg')) .
                        $q->li('Paging' .
                                $self->image_check('sar/sar-paging.png') .
                                $self->image_check('sar/sar-paging.svg')) .
                        $q->li('Processes Created' .
                                $self->image_check('sar/sar-proc_s.png') .
                                $self->image_check('sar/sar-proc_s.svg')) .
                        $q->li('RT Signals' .
                                $self->image_check('sar/sar-rtsig-sz.png') .
                                $self->image_check('sar/sar-rtsig-sz.svg')) .
                        $q->li('Super Block Handlers' .
                                $self->image_check('sar/sar-super-sz.png') .
                                $self->image_check('sar/sar-super-sz.svg')) .
                        $q->li('Swapping' .
                                $self->image_check('sar/sar-swapping.png') .
                                $self->image_check('sar/sar-swapping.svg'))
                )
        );
    }

    if (-d "$self->{outdir}/report/vmstat") {
        $h .= $q->h3('vmstat [' . $q->a({href => '../vmstat.out'}, 'Raw Data') .
                ']');
        $h .= $q->p(
                $q->ul(
                        $q->li('Processor Utilization' .
                                $self->image_check('vmstat/vmstat-cpu.png') .
                                $self->image_check('vmstat/vmstat-cpu.svg')) .
                        $q->li('Context Switches' .
                                $self->image_check('vmstat/vmstat-cs.png') .
                                $self->image_check('vmstat/vmstat-cs.svg')) .
                        $q->li('Interrupts' .
                                $self->image_check('vmstat/vmstat-in.png') .
                                $self->image_check('vmstat/vmstat-in.svg')) .
                        $q->li('I/O' .
                                $self->image_check('vmstat/vmstat-io.png') .
                                $self->image_check('vmstat/vmstat-io.svg')) .
                        $q->li('Memory' .
                                $self->image_check('vmstat/vmstat-memory.png') .
                                $self->image_check(
                                        'vmstat/vmstat-memory.svg')) .
                        $q->li('Processes' .
                                $self->image_check('vmstat/vmstat-procs.png') .
                                $self->image_check('vmstat/vmstat-procs.svg')) .
                        $q->li('Swapping' .
                                $self->image_check('vmstat/vmstat-swap.png') .
                                $self->image_check('vmstat/vmstat-swap.svg'))
                )
        );
    }

    if (-d "$self->{outdir}/report/iostat") {
        $h .= $q->h3('iostat [' . $q->a({href => '../iostatx.out'},
                'Raw Data') . ']');
        $h .= $q->p($self->iostat_links('iostat'));
    }

    if (-d "$self->{outdir}/report/iostat/log") {
        $h .= $q->h4('Logs');
        $h .= $q->p($self->iostat_links('iostat/log'));
    }

    $h .= $q->h4('Tables');

    if (-d "$self->{outdir}/report/iostat/customer") {
        $h .= $q->h5('Customer Tablespace');
        $h .= $q->p($self->iostat_links('iostat/customer'));
    }

    if (-d "$self->{outdir}/report/iostat/district") {
        $h .= $q->h5('District Tablespace');
        $h .= $q->p($self->iostat_links('iostat/district'));
    }

    if (-d "$self->{outdir}/report/iostat/history") {
        $h .= $q->h5('History Tablespace');
        $h .= $q->p($self->iostat_links('iostat/history'));
    }

    if (-d "$self->{outdir}/report/iostat/history") {
        $h .= $q->h5('History Tablespace');
        $h .= $q->p($self->iostat_links('iostat/history'));
    }

    if (-d "$self->{outdir}/report/iostat/item") {
        $h .= $q->h5('Item Tablespace');
        $h .= $q->p($self->iostat_links('iostat/item'));
    }

    if (-d "$self->{outdir}/report/iostat/new_order") {
        $h .= $q->h5('New Order Tablespace');
        $h .= $q->p($self->iostat_links('iostat/new_order'));
    }

    if (-d "$self->{outdir}/report/iostat/order_line") {
        $h .= $q->h5('Order Line Tablespace');
        $h .= $q->p($self->iostat_links('iostat/order_line'));
    }

    if (-d "$self->{outdir}/report/iostat/orders") {
        $h .= $q->h5('Orders Tablespace');
        $h .= $q->p($self->iostat_links('iostat/orders'));
    }

    if (-d "$self->{outdir}/report/iostat/stock") {
        $h .= $q->h5('Stock Tablespace');
        $h .= $q->p($self->iostat_links('iostat/stock'));
    }

    if (-d "$self->{outdir}/report/iostat/warehouse") {
        $h .= $q->h5('Warehouse Tablespace');
        $h .= $q->p($self->iostat_links('iostat/warehouse'));
    }

    $h .= $q->h4('Indexes');

    if (-d "$self->{outdir}/report/iostat/index1") {
        $h .= $q->h5('Index1 Tablespace');
        $h .= $q->p($self->iostat_links('iostat/index1'));
    }

    if (-d "$self->{outdir}/report/iostat/index2") {
        $h .= $q->h5('Index2 Tablespace');
        $h .= $q->p($self->iostat_links('iostat/index2'));
    }

    if (-d "$self->{outdir}/report/iostat/pkcustomer") {
        $h .= $q->h5('Customer Primary Key Tablespace');
        $h .= $q->p($self->iostat_links('iostat/pkcustomer'));
    }

    if (-d "$self->{outdir}/report/iostat/pkdistrict") {
        $h .= $q->h5('District Primary Key Tablespace');
        $h .= $q->p($self->iostat_links('iostat/pkdistrict'));
    }

    if (-d "$self->{outdir}/report/iostat/pkitem") {
        $h .= $q->h5('Item Primary Key Tablespace');
        $h .= $q->p($self->iostat_links('iostat/pkitem'));
    }

    if (-d "$self->{outdir}/report/iostat/pknew_order") {
        $h .= $q->h5('New Order Primary Key Tablespace');
        $h .= $q->p($self->iostat_links('iostat/pknew_order'));
    }

    if (-d "$self->{outdir}/report/iostat/pkorder_line") {
        $h .= $q->h5('Order Line Primary Key Tablespace');
        $h .= $q->p($self->iostat_links('iostat/pkorder_line'));
    }

    if (-d "$self->{outdir}/report/iostat/pkorders") {
        $h .= $q->h5('Orders Primary Key Tablespace');
        $h .= $q->p($self->iostat_links('iostat/pkorders'));
    }

    if (-d "$self->{outdir}/report/iostat/pkstock") {
        $h .= $q->h5('Stock Primary Key Tablespace');
        $h .= $q->p($self->iostat_links('iostat/pkstock'));
    }

    if (-d "$self->{outdir}/report/iostat/pkwarehouse") {
        $h .= $q->h5('Warehouse Primary Key Tablespace');
        $h .= $q->p($self->iostat_links('iostat/pkwarehouse'));
    }

    $h .= $q->end_html;
    return $h;
}

sub iostat_links {
    my $self = shift;
    my $dir = shift;

    my $q = new CGI;

    my $h = $q->ul(
            $q->li('Average Queue Length' .
                    $self->image_check("$dir/iostat-avgqu.png") .
                    $self->image_check("$dir/iostat-avgqu.svg")) .
            $q->li('Average Request Size' .
                    $self->image_check("$dir/iostat-avgrq.png") .
                    $self->image_check("$dir/iostat-avgrq.svg")) .
            $q->li('Average Request Time' .
                    $self->image_check("$dir/iostat-await.png") .
                    $self->image_check("$dir/iostat-await.svg")) .
            $q->li('Read/Write Kilobytes' .
                    $self->image_check("$dir/iostat-kb.png") .
                    $self->image_check("$dir/iostat-kb.svg")) .
            $q->li('Read/Write Requests Merged' .
                    $self->image_check("$dir/iostat-rqm.png") .
                    $self->image_check("$dir/iostat-rqm.svg")) .
            $q->li('Read/Write Requests' .
                    $self->image_check("$dir/iostat-rw.png") .
                    $self->image_check("$dir/iostat-rw.svg")) .
            $q->li('Read/Write Sectors' .
                    $self->image_check("$dir/iostat-sec.png") .
                    $self->image_check("$dir/iostat-sec.svg")) .
            $q->li('Average Service Time' .
                    $self->image_check("$dir/iostat-svctm.png") .
                    $self->image_check("$dir/iostat-svctm.svg")) .
            $q->li('Disk Utilization' .
                    $self->image_check("$dir/iostat-util.png") .
                    $self->image_check("$dir/iostat-util.svg"))
    );
    return $h;
}

=head3 image_check()

Returns an HTML href a file exists.

=cut
sub image_check {
    my $self = shift;
    my $filename = shift;
    my $link = shift;

    my $q = new CGI;

    $filename =~ /.*\.(.*)/;
    my $format = $1;

    my $h = '';
    if (-f "$self->{outdir}/report/$filename") {
        $h .= ' [' . $q->a({href => $filename}, $format) . ']';
    }
    return $h;
}

=head3 to_xml()

Returns sar data transformed into XML.

=cut
sub to_xml {
    my $self = shift;
    return XMLout({%{$self->{data}}}, RootName => 'dbt2',
            OutputFile => "$self->{outdir}/report/result.xml");
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

