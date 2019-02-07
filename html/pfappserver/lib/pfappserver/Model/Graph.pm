package pfappserver::Model::Graph;

=head1 NAME

pfappserver::Model::Graph - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use Moose;
use namespace::autoclean;

use Date::Parse;
use pf::log;
use pf::config::ui;
use pf::error qw(is_error is_success);
use pf::pfcmd::graph;
use pf::pfcmd::report;

extends 'Catalyst::Model';

=head1 METHODS

=head2 _round

=cut

sub _round {
    my $number = shift;

    if ($number > 1000) {
        return int($number/100 + 0.5)/10 . 'K';
    }

    return $number;
}

=head2 count

=cut

sub countAll {
    my ($self, $module, $params) = @_;
    my $logger = get_logger();

    my ($status, $status_msg);
    my (@results, $result);
    my $function = \&{"pf::${module}::${module}_count_all"};

    if ($function) {
        eval {
            require pf::node if ($module eq 'node');
            @results = $function->(undef, ( where => $params )); };
        if ($@) {
            $logger->error($@);
            $status_msg = ["Can't count data from database for module [_1].",$module];
            return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
        }
    }
    else {
        $status_msg = ["No such sub [_1]",$function];
        return ($STATUS::NOT_FOUND, $status_msg);
    }

    $result = pop @results;
    $result->{nb} = _round($result->{nb});

    return ($STATUS::OK, $result);
}

=head2 timeBase

From bin/pfcmd (print_graph_results)

TODO: restore the interval parameter (day/month/year)

=cut

sub timeBase {
    my ($self, $graph, $startDate, $endDate, $options) = @_;
    my $logger = get_logger();
    my ($status, $status_msg);

    my $first_time = undef;
    my $last_time  = undef;
    my $function = \&{"pf::pfcmd::graph::graph_$graph"};
    my $interval = 'day';
    my @data = ();
    my @results;
    my %series;

    # Switch to a month interval if period covers more than 90 days
    if ($startDate && $endDate) {
        my ($start_year, $start_mon, $start_day) = split( /\-/, $startDate);
        my ($end_year, $end_mon, $end_day) = split( /\-/, $endDate);
        $first_time = Date::Parse::str2time("$start_year-$start_mon-$start_day" . "T00:00:00.0000000" );
        $last_time = Date::Parse::str2time("$end_year-$end_mon-$end_day" . "T23:59:59.0000000" );

        if ( ($last_time - $first_time) > (90 * 24 * 60 * 60) ) {
            $interval = 'month';
            $start_day = $end_day = 1;
            $first_time = Date::Parse::str2time("$start_year-$start_mon-$start_day" . "T00:00:00.0000000" );
            $last_time = Date::Parse::str2time("$end_year-$end_mon-$end_day" . "T00:00:00.0000000" );
        }
    }

    if ($function) {
        eval { @results = $function->("$startDate 00:00:00", "$endDate 23:59:59", $interval); };
        if ($@) {
            $status_msg = ["Can't fetch data from database for graph [_1].", $graph];
            $logger->error($@);
            return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
        }
    }
    else {
        $status_msg = ["No such sub [_1]", $function];
        return ($STATUS::NOT_FOUND, $status_msg);
    }

    foreach my $result (@results) {
        next if ( $result->{'mydate'} =~ /0000/ );
        my $s = $result->{'series'};
        push( @{ $series{$s} }, $result );
    }
    my @fields = keys( %{ $results[0] } );
    push(@data, \@fields) if (@fields);

    unless ($startDate && $endDate) {
        # TODO: do we check the last date of the series or simply take today as the end date?
        $last_time = localtime();

        foreach my $s ( keys(%series) ) {
            my $start_year;
            my $start_mon = 1;
            my $start_day = 1;
            my @results = @{ $series{$s} };
            if ( $interval eq "day" ) {
                ( $start_year, $start_mon, $start_day )
                  = split( /\//, $results[0]->{'mydate'} );
            } elsif ( $interval eq "month" ) {
                ( $start_year, $start_mon )
                  = split( /\//, $results[0]->{'mydate'} );
            } elsif ( $interval eq "year" ) {
                $start_year = $results[0]->{'mydate'};
            }
            my $start_time = Date::Parse::str2time("$start_year-$start_mon-$start_day" . "T00:00:00.0000000");
            if ( ( !defined($first_time) ) || ( $start_time < $first_time ) ) {
                $first_time = $start_time;
            }
        }
    }

    # Add, if necessary, first and last time entries to all series
    foreach my $s ( keys(%series) ) {
        my $start_year;
        my $start_mon = 1;
        my $start_day = 1;
        my $end_year;
        my $end_mon = 1;
        my $end_day = 1;
        my @results = @{ $series{$s} };
        if ( $interval eq "day" ) {
            ( $start_year, $start_mon, $start_day )
                = split( /\//, $results[0]->{'mydate'} );
            ( $end_year, $end_mon, $end_day )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
        } elsif ( $interval eq "month" ) {
            ( $start_year, $start_mon )
                = split( /\//, $results[0]->{'mydate'} );
            ( $end_year, $end_mon )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
        } elsif ( $interval eq "year" ) {
            $start_year = $results[0]->{'mydate'};
            $end_year   = $results[ scalar(@results) - 1 ]->{'mydate'};
        }
        my $start_time = Date::Parse::str2time(
            "$start_year-$start_mon-$start_day" . "T00:00:00.0000000" );
        my $end_time = Date::Parse::str2time(
            "$end_year-$end_mon-$end_day" . "T23:59:59.0000000" );
        if ( $start_time > $first_time ) {
            my $new_record;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    $new_record->{$field} = POSIX::strftime( "%Y/%m/%d",
                        localtime($first_time) );
                } elsif ( $field eq "count" ) {
                    $new_record->{$field} = 0;
                } else {
                    $new_record->{$field}
                        = $results[$#results]->{$field};
                }
            }
            unshift( @{$series{$s}}, $new_record );
        }
        if ( $end_time < $last_time ) {
            my $new_record;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    $new_record->{$field} = POSIX::strftime( "%Y/%m/%d",
                        localtime($last_time) );
                } elsif ( $field eq "count" ) {
                    $new_record->{$field} = 0;
                } else {
                    $new_record->{$field}
                        = $results[$#results]->{$field};
                }
            }
            push( @{$series{$s}}, $new_record );
        }
    }

    # Fill gap between every pair of dates
    foreach my $s ( keys(%series) ) {
        my @results = @{ $series{$s} };

        push( @results, $results[0] ) if ( scalar(@results) == 1 );
        if ( $interval eq "day" ) {
            for ( my $r = 0; $r < $#results; $r++ ) {
                my ( $start_year, $start_mon, $start_day )
                    = split( /\//, $results[$r]->{'mydate'} );
                my ( $end_year, $end_mon, $end_day )
                    = split( /\//, $results[ $r + 1 ]->{'mydate'} );
                my $start_time
                  = Date::Parse::str2time("$start_year-$start_mon-$start_day" . "T00:00:00.0000000");
                my $end_time
                  = Date::Parse::str2time("$end_year-$end_mon-$end_day" . "T00:00:00.0000000");
                for (my $current_time = $start_time;
                     $current_time < $end_time;
                     $current_time += 86400)
                {
                    my @values;
                    foreach my $field (@fields) {
                        if ( $field eq "mydate" ) {
                            push(
                                @values,
                                POSIX::strftime(
                                    "%m/%d/%Y", localtime($current_time)
                                )
                            );
                        }
                        elsif ( $field eq 'count' ) {
                            if ($current_time == $start_time || $options->{continuous}) {
                                push( @values, $results[$r]->{$field} );
                            }
                            else {
                                push( @values, 0 );
                            }
                        }
                        else {
                            push( @values, $results[$r]->{$field} );
                        }
                    }
                    push(@data, \@values);
                }
            }

            my @values;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    my ( $year, $mon, $day )
                      = split( /\//, $results[$#results]->{'mydate'} );
                    push(
                        @values,
                        join( "/",
                            sprintf( "%02d", $mon ),
                            sprintf( "%02d", $day ),
                            sprintf( "%02d", $year ) )
                    );
                } else {
                    push( @values,
                        $results[$#results]->{$field} );
                }
            }
            push(@data, \@values);

        }
        elsif ( $interval eq "month" ) {
            for ( my $r = 0; $r < scalar(@results) - 1; $r++ ) {
                my ( $start_year, $start_mon )
                    = split( /\//, $results[$r]->{'mydate'} );
                my ( $end_year, $end_mon )
                    = split( /\//, $results[ $r + 1 ]->{'mydate'} );
                my $mstart = $start_mon;
                for ( my $i = $start_year; $i <= $end_year; $i++ ) {
                    my $mend;
                    if ( $i == $end_year ) {
                        $mend = $end_mon;
                    } else {
                        $mend = "12";
                    }
                    for ( my $ii = $mstart; $ii <= $mend; $ii++ ) {
                        if ( !( $i == $end_year && $ii == $end_mon ) ) {
                            my @values;
                            foreach my $field (@fields) {
                                if ( $field eq "mydate" ) {
                                    push(
                                        @values,
                                        join( "/",
                                            sprintf( "%02d", $ii ),
                                            sprintf( "%02d", $i ) )
                                    );
                                }
                                elsif ( $field eq 'count' ) {
                                    if ($start_year == $i && $mstart == $ii || $options->{continuous}) {
                                        push( @values, $results[$r]->{$field} );
                                    }
                                    else {
                                        push( @values, 0 );
                                    }
                                }
                                else {
                                    push( @values, $results[$r]->{$field} );
                                }
                            }
                            push(@data, \@values);
                        }
                    }
                    $mstart = 1;
                }
            }
            my ( $year, $mon )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
            my @values;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    push(
                        @values,
                        join( "/",
                            sprintf( "%02d", $mon ),
                            sprintf( "%02d", $year ) )
                    );
                } else {
                    push( @values,
                        $results[ scalar(@results) - 1 ]->{$field} );
                }
            }
            push(@data, \@values);
        }
        elsif ( $interval eq "year" ) {
            for ( my $r = 0; $r < scalar(@results) - 1; $r++ ) {
                my ($start_year) = $results[$r]->{'mydate'};
                my ($end_year)   = $results[ $r + 1 ]->{'mydate'};
                for ( my $i = $start_year; $i <= $end_year; $i++ ) {
                    if ( !( $i == $end_year ) ) {
                        my @values;
                        foreach my $field (@fields) {
                            if ( $field eq "mydate" ) {
                                push( @values, sprintf( "%02d", $i ) );
                            } else {
                                push( @values, $results[$r]->{$field} );
                            }
                        }
                        push(@data, \@values);
                    }
                }
            }
            my ($year) = $results[ scalar(@results) - 1 ]->{'mydate'};
            my @values;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    push( @values, sprintf( "%02d", $year ) );
                } else {
                    push( @values,
                          $results[ scalar(@results) - 1 ]->{$field} );
                }
            }
            push(@data, \@values);
        }
    }

    push (@data, [qw/count mydate series/]) unless (@data);

    return ($STATUS::OK, _format_timeBase(\@data));
}

=head2 _format_timeBase

=cut

sub _format_timeBase {
    my $data = shift;

    my %labels = ();
    my %series = ();
    my $results = {};

    # Expected headers from $data are : count, mydate, series
    my $headers = shift @{$data};
    my $index = {};
    for (my $i = 0; $i < scalar(@{$headers}); $i++) {
        $index->{${$headers}[$i]} = $i;
    }

    my $formatMonth;
    foreach my $row (@{$data}) {
        my $mydate = ${$row}[$index->{mydate}];
        if ($mydate =~ m|^(\d{1,2})/(\d{4})$|) {
            # Make sure the format is MM/D/YYYY for sorting
            $mydate = "$1/1/$2";
            $formatMonth = 1;
        }
        $labels{$mydate} = 1;
        unless ($series{${$row}[$index->{series}]}) {
            $series{${$row}[$index->{series}]} = {};
        }
        $series{${$row}[$index->{series}]}->{$mydate} = ${$row}[$index->{count}];
    }

    my @sorted_labels = map {  $_->[0] }
                        sort { $a->[3] <=> $b->[3]    # year
                            || $a->[1] <=> $b->[1]    # month
                            || $a->[2] <=> $b->[2] }  # day
                        map { [ $_, split /\// ] }
                        keys %labels;
    $results->{labels} = \@sorted_labels;
    $results->{series} = {};
    foreach my $label (@{$results->{labels}}) {
        foreach my $set (keys %series) {
            $results->{series}->{$set} = [] unless ($results->{series}->{$set});
            unless ($series{$set}->{$label}) {
                $series{$set}->{$label} = '0';
            }
            push(@{$results->{series}->{$set}}, $series{$set}->{$label});
        }
    }
    if ($formatMonth) {
        # Remove the day (MM/1/YYYY) added above
        s|/1/|/| for (@sorted_labels);
        $results->{labels} = \@sorted_labels;
    }

    return $results;
}

=head2 ratioBase

See bin/pfcmd (report)

=cut

sub ratioBase {
    my ( $self, $report, $startDate, $endDate, $options ) = @_;
    my $logger = get_logger();
    my ( $status, $status_msg );

    my $function = \&{"pf::pfcmd::report::report_${report}"};

    my @results;
    if ($function) {
        eval { @results = $function->($startDate, $endDate); };
        if ($@) {
            $logger->error($@);
            $status_msg = ["Can't fetch data from database for report [_1].",$report];
            return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
        }
    }
    else {
        $status_msg = ["No such sub [_1]",$function];
        return ($STATUS::NOT_FOUND, $status_msg);
    }

    my $results_formatted = _format_ratioBase(\@results,
                                         $options->{fields}->{label},
                                         $options->{fields}->{count},
                                         $options->{fields}->{value});

    return ($STATUS::OK, $results_formatted);
}

=head2 _format_ratioBase

=cut

sub _format_ratioBase {
    my ($data, $description_field, $count_field, $value_field) = @_;

    my (@rows, @labels, @values, @display, @items);
    my $results = {};

    $value_field = $count_field unless ($value_field);

    # Drop the "total"
    my $total = pop @$data;
    $total = int $total->{$count_field};

    return unless ($total > 0);


    # Extract only the necessary fields
    foreach my $row (sort { $b->{$count_field} <=> $a->{$count_field}} @{$data}) {
        my $label = $row->{$description_field};
        my $value = $row->{$count_field};
        my $display = $row->{$value_field};
        push @labels, $label;
        push @values, $value;
        push @display, $display;
        push @items, {%$row, label => $label, value => $value, display => $display};
    }

    # Compute the last row that will appears in the pie chart
    # See https://github.com/DmitryBaranovskiy/g.raphael/blob/master/g.pie.js
    my $cut = 9;
    my $i = 0;
    for my $item (@items) {
        if ($item->{value} * 360 / $total <= 1.5) {
            $cut = $i;
            last;
        }
    }
    $cut = 9 if ($cut > 9);
    $cut++ if ($cut + 1 == scalar @items);

    $results->{labels} = \@labels;
    $results->{series} = { values => \@values }; # Structure is suitable for g.raphael.js
    $results->{values} = \@display;
    $results->{piecut} = $cut;
    $results->{items}  = \@items;

    return $results;
}

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
