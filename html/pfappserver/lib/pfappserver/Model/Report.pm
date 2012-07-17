package pfappserver::Model::Report;

=head1 NAME

pfappserver::Model::Report - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use Moose;
use namespace::autoclean;

use pf::config;
use pf::pfcmd::report;

extends 'Catalyst::Model';

=head1 METHODS

=head2 results

See bin/pfcmd (report)

=cut
sub results {
    my ( $self, $report, $options ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ( $status, $status_msg );

    my $function = \&{"pf::pfcmd::report::report_${report}_" . $options->{report}};

    my @results;
    if ($function) {
        eval { @results = $function->(); };
        if ($@) {
            $status_msg = "Can't fetch data from database for report $report.";
            $logger->error($@);
            return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
        }
    }
    else {
        $status_msg = "No such sub $function";
        return ($STATUS::NOT_FOUND, $status_msg);
    }

    my $results_formatted = _format_data(\@results,
                                         $options->{fields}->{label},
                                         $options->{fields}->{count},
                                         $options->{fields}->{value});

    return ($STATUS::OK, $results_formatted);
}

=head2 _format_data

=cut
sub _format_data {
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
