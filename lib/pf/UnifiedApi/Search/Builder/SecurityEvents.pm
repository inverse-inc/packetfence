package pf::UnifiedApi::Search::Builder::SecurityEvents;

=head1 NAME

pf::UnifiedApi::Search::Builder::SecurityEvents -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Search::Builder::SecurityEvents

=cut

use strict;
use warnings;
use Moo;
extends qw(pf::UnifiedApi::Search::Builder);
use pf::dal::node;

our @NODES_JOIN = (
    '=>{node.mac=security_event.mac}', 'node',
);

our %ALLOWED_JOIN_FIELDS = (
    map_dal_fields_to_join_spec("pf::dal::node", \@NODES_JOIN, undef, {}),
);

sub map_dal_fields_to_join_spec {
    my ($dal, $join_spec, $where_spec, $exclude) = @_;
    $exclude //= {};
    my $table = $dal->table;
    return map { map_dal_field_to_join_spec($table, $_,$join_spec, $where_spec) } grep {!exists $exclude->{$_}} @{$dal->table_field_names}; 
}

sub map_dal_field_to_join_spec {
    my ($table, $field, $join_spec, $where_spec) = @_;
    return "${table}.${field}" => {
        join_spec => $join_spec,
        namespace => $table,
        (defined $where_spec ? (where_spec => $where_spec) : () ),
        column_spec => make_join_column_spec($table, $field),
   } 
}

sub make_join_column_spec {
    my ($t, $f) = @_;
    return \"`${t}`.`${f}` AS `${t}.${f}`";
}

sub allowed_join_fields {
    \%ALLOWED_JOIN_FIELDS
}

=head1 AUTHOR 

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
