package pfappserver::Model::Graph;

=head1 NAME

pfappserver::Model::Graph - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use Moose;
use namespace::autoclean;

use Date::Parse;
use pf::config::ui;
use pf::error qw(is_error is_success);
use pf::pfcmd::graph;
use pf::pfcmd::report;

extends 'Catalyst::Model';

=head1 METHODS

=head2 field_order

From pf::config::ui

=cut
sub field_order {
    return pf::config::ui->instance->field_order("@ARGV");
}

=head2 timeBase

From bin/pfcmd (print_graph_results)

=cut
sub timeBase {
    my ( $self, $graph, $interval ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ( $status, $status_msg );

    my $function = \&{"pf::pfcmd::graph::graph_$graph"};
    $interval = 'day' unless (defined($interval));

    my @data = ();
    my @results;
    if ($function) {
        eval { @results = $function->($interval); };
        if ($@) {
            $status_msg = "Can't fetch data from database for graph $graph.";
            $logger->error($@);
            return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
        }
    }
    else {
        $status_msg = "No such sub $function";
        return ($STATUS::NOT_FOUND, $status_msg);
    }

    my %series;
    foreach my $result (@results) {
        next if ( $result->{'mydate'} =~ /0000/ );
        my $s = $result->{'series'};
        push( @{ $series{$s} }, $result );
    }
    my @fields = field_order();
    push @fields, keys( %{ $results[0] } ) if ( !scalar(@fields) );
    push(@data, \@fields);

    #determine first and last time in all series
    my $first_time = undef;
    my $last_time  = undef;
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
            "$end_year-$end_mon-$end_day" . "T00:00:00.0000000" );
        if ( ( !defined($first_time) ) || ( $start_time < $first_time ) ) {
            $first_time = $start_time;
        }
        if ( ( !defined($last_time) ) || ( $end_time > $last_time ) ) {
            $last_time = $end_time;
        }
    }

    #add, if necessary, first and last time entries to all series
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
            "$end_year-$end_mon-$end_day" . "T00:00:00.0000000" );
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
                        = $results[ scalar(@results) - 1 ]->{$field};
                }
            }
            unshift( @{ $series{$s} }, $new_record );
        }
        if ( $end_time < $last_time ) {
            my $new_record;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    $new_record->{$field} = POSIX::strftime( "%Y/%m/%d",
                        localtime($last_time) );
                } else {
                    $new_record->{$field}
                        = $results[ scalar(@results) - 1 ]->{$field};
                }
            }
            push( @{ $series{$s} }, $new_record );
        }
    }

    foreach my $s ( keys(%series) ) {
        my @results = @{ $series{$s} };
        my $year    = POSIX::strftime( "%Y", localtime );
        my $month   = POSIX::strftime( "%m", localtime );
        my $day     = POSIX::strftime( "%d", localtime );
        my $date;
        if ( $interval eq "day" ) {
            $date = "$year/$month/$day";
        } elsif ( $interval eq "month" ) {
            $date = "$year/$month";
        } elsif ( $interval eq "year" ) {
            $date = "$year";
        } else {
        }
        if ( $results[ scalar(@results) - 1 ]->{'mydate'} ne $date ) {
            my %tmp = %{ $results[ scalar(@results) - 1 ] };
            $tmp{'mydate'} = $date;
            push( @results, \%tmp );
        }
        push( @results, $results[0] ) if ( scalar(@results) == 1 );
        if ( $interval eq "day" ) {
            for ( my $r = 0; $r < scalar(@results) - 1; $r++ ) {
                my ( $start_year, $start_mon, $start_day )
                    = split( /\//, $results[$r]->{'mydate'} );
                my ( $end_year, $end_mon, $end_day )
                    = split( /\//, $results[ $r + 1 ]->{'mydate'} );
                my $start_time
                    = Date::Parse::str2time(
                          "$start_year-$start_mon-$start_day"
                        . "T00:00:00.0000000" );
                my $end_time = Date::Parse::str2time(
                    "$end_year-$end_mon-$end_day" . "T00:00:00.0000000" );
                for (
                    my $current_time = $start_time;
                    $current_time < $end_time;
                    $current_time += 86400
                    )
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
                        } else {
                            push( @values, $results[$r]->{$field} );
                        }
                    }
                    push(@data, \@values);
                }
            }
            my ( $year, $mon, $day )
                = split( /\//, $results[ scalar(@results) - 1 ]->{'mydate'} );
            my @values;
            foreach my $field (@fields) {
                if ( $field eq "mydate" ) {
                    push(
                        @values,
                        join( "/",
                            sprintf( "%02d", $mon ),
                            sprintf( "%02d", $day ),
                            sprintf( "%02d", $year ) )
                    );
                } else {
                    push( @values,
                        $results[ scalar(@results) - 1 ]->{$field} );
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
                                } else {
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

    return ($STATUS::OK, _format_timeBase(\@data));
}

=head2 _format_timeBase

=cut
sub _format_timeBase {
    my $data = shift;

    my %labels = ();
    my %series = ();
    my $results = {};

    # Expected headers from date are : count, mydate, series
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
    my ( $self, $report, $options ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ( $status, $status_msg );

    my $function = \&{"pf::pfcmd::report::report_${report}_" . $options->{report}};

    my @results;
    if ($function) {
        eval { @results = $function->(); };
        if ($@) {
            $logger->error($@);
            $status_msg = "Can't fetch data from database for report $report.";
            return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
        }
    }
    else {
        $status_msg = "No such sub $function";
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

    my @rows;
    my $results = {};

    $value_field = $count_field unless ($value_field);

    # Drop the "total"
    my $total = pop @$data;
    $total = int $total->{$count_field};

    # Extract only the necessary fields
    foreach my $row (@{$data}) {
        push(@rows, [$row->{$description_field}, $row->{$count_field}, $row->{$value_field}]);
    }

    my @sorted_rows = sort { $b->[1] <=> $a->[1] } @rows; # descending
    my @labels  = map { $_->[0] } @sorted_rows;
    my @values  = map { $_->[1] } @sorted_rows;
    my @display = map { $_->[2] } @sorted_rows;

    # Compute the last row that will appears in the pie chart
    # See https://github.com/DmitryBaranovskiy/g.raphael/blob/master/g.pie.js
    my $cut = 9;
    my $i;
    for ($i = 0; $i < scalar @sorted_rows; $i++) {
        my $row = $sorted_rows[$i];
        if ($row->[1] * 360 / $total <= 1.5) {
            $cut = $i;
            last;
        }
    }
    $cut = 9 if ($cut > 9);
    $cut++ if ($cut + 1 == scalar @sorted_rows);

    $results->{labels} = \@labels;
    $results->{series} = { values => \@values }; # Structure is suitable for g.raphael.js
    $results->{values} = \@display;
    $results->{piecut} = $cut;

    return $results;
}

=head1 AUTHOR

Francis Lachapelle <flachapelle@inverse.ca>

=head1 COPYRIGHT

Copyright 2012 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;
