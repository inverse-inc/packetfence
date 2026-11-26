package pf::UnifiedApi::Search::Builder::Locationlogs;

=head1 NAME

pf::UnifiedApi::Search::Builder::Locationlogs -

=head1 DESCRIPTION

pf::UnifiedApi::Search::Builder::Locationlogs

=cut

use strict;
use warnings;
use Moo;
extends qw(pf::UnifiedApi::Search::Builder);
use pf::error qw(is_error);
use pf::dal::locationlog_history;
use pf::dal::locationlog;
use Clone qw();

sub make_search_args {
    my ($self, $search_info) = @_;
    my $locationlog_history_search_info = Clone::clone($search_info);
    my ($status, $search_args) = $self->SUPER::make_search_args($search_info);
    if (is_error($status)) {
        return ($status, $search_args);
    }

    $locationlog_history_search_info->{dal} = "pf::dal::locationlog_history";
    ($status,  my $lh_search_args) = $self->SUPER::make_search_args($locationlog_history_search_info);

    $search_args->{'-union_all'} = [
       pf::dal::locationlog_history->update_params_for_select(
           -columns => $lh_search_args->{'-columns'},
           -from => 'locationlog_history',
           -where => $lh_search_args->{'-where'},
       )
    ];

    return ($status, $search_args);
}

=head2 $self->order_by_column($search_info, $field)

The search is a union of locationlog and locationlog_history, so table fields
are sorted on their column name, without the table prefix

=cut

sub order_by_column {
    my ($self, $s, $f) = @_;
    if ($self->is_table_field($s, $f)) {
        return $self->table_column($s, $f);
    }

    return $self->SUPER::order_by_column($s, $f);
}

=head2 default_columns

default_columns

=cut

sub default_columns {
    my ($self, $s) = @_;
    return [grep { $_ ne 'id'} @{$s->{dal}->table_field_names}];
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

