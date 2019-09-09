package pf::UnifiedApi::Search::Builder::NodesNetworkGraph;

=head1 NAME

pf::UnifiedApi::Search::Builder::NodesNetworkGraph - Nodes NetworkGraph search builder

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Search::Builder::Nodes

=cut

use strict;
use warnings;
use Moo;
use pf::error qw(is_error);
use List::MoreUtils qw(none);
extends qw(pf::UnifiedApi::Search::Builder::Nodes);

=head2 $self->make_columns($search_info)

Make the SQL::Abstract::More columns from the search_info

    my ($http_status, $columns_or_error) = $self->make_columns($search_info);

=cut

my @NEEDED_FIELDS = (
    'locationlog.switch',
    'mac',
);

sub make_columns {
    my ( $self, $s ) = @_;
    my $cols = $s->{fields} // [];
    if (@$cols == 0) {
        @$cols = @NEEDED_FIELDS;
    } else {
        #add the needed fields
        my %needed = map { $_ => undef } @NEEDED_FIELDS;
        delete $needed{$_} for @$cols;
        push @$cols, keys %needed;
    }

    my @errors = map { {message => "$_ is an invalid field" } } grep { !$self->is_valid_field($s, $_) } @$cols;
    if (@errors) {
        return 422,
          {
            message    => "Invalid column(s) defined",
            errors => \@errors
          };
    }

    my ($status, $error) = $self->check_for_duplicated_fields($cols);
    if (is_error($status)) {
        return $status, $error;
    }

    if (@$cols) {
        push @{$s->{found_fields}}, @$cols;
        @$cols = map { $self->format_column($s, $_) } @$cols
    } else {
        $cols = [@{$s->{dal}->table_field_names}];
    }

    if ($s->{with_total_count}) {
        unshift @$cols, '-SQL_CALC_FOUND_ROWS';
    }

    return 200, $cols;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;
