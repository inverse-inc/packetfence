package pfappserver::Model::RadiusLog;

=head1 NAME

pfappserver::Model::RadiusLog - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

use Moose;
use namespace::autoclean;
use pf::radius_audit_log;
use pf::error qw(is_error is_success);
use SQL::Abstract::More;

=head1 METHODS


=head2 view

View a radius audit log entry

=cut

sub view {
    my ($self, $id) = @_;
    my $item = radius_audit_log_view($id);
    return ($STATUS::OK,$item) if $item;
    return ($STATUS::NOT_FOUND,["Item [_1] not found", $id]);
}

sub view_entries {
    my ($self, $page_number, $items_per_page) = @_;
    $page_number ||= 1;
    $items_per_page ||= 25;
    my $offset = $page_number - 1;
    $offset = 0 if $offset < 0;
    my @items = radius_audit_log_view_all($offset, $items_per_page);
    return ($STATUS::OK,\@items);
}

sub search {
    my ($self, $params) = @_;
    my $sqla = SQL::Abstract::More->new;
    my ($sql, @bind) = $sqla->select(
        -from => $self->table,
        $self->_build_where($params),
        $self->_build_limit($params),
    );
    my @items =  radius_audit_log_custom($sql, @bind);
    return ($STATUS::OK,\@items);
}

sub _build_where {
    my ($self, $params) = @_;
    my $searches = $params->{searches};
    my $all_or_any = $params->{all_or_any} // "any";
    my $relational_op = $all_or_any eq "any" ? "-or" : "-and";
    my @clauses = map { $self->_build_clause($_) } @$searches;
    return -where => {
        $relational_op => \@clauses,
    };
}

sub _build_limit {
    my ($self, $params) = @_;
    my $page_num = $params->{page_num} || 1;
    my $limit  = $params->{per_page} || 25;
    my $offset = (( $page_num - 1 ) * $limit);
    return (-limit => $limit, -offset => $offset);
}

our %OP_MAP = (
    equal       => '=',
    not_equal   => '<>',
    not_like    => 'NOT LIKE',
    like        => 'LIKE',
    ends_with   => 'LIKE',
    starts_with => 'LIKE',
    in          => 'IN',
    not_in      => 'NOT IN',
);

=head2 _build_clause

=cut

sub _build_clause {
    my ($self, $query) = @_;
    my $op = $query->{op};
    die "$op is not a supported search operation"
        unless exists $OP_MAP{$op};
    my $sql_op = $OP_MAP{$op};
    my $value = $query->{value};
    my $name = $query->{name};
    if($sql_op eq 'LIKE' || $sql_op eq 'NOT LIKE') {
        #escaping the % and _ charcaters
        my $escaped = $value =~ s/([%_])/\\$1/g;
        if($op eq 'like' || $op eq 'not_like') {
            $value = "\%$value\%";
        } elsif ($op eq 'starts_with') {
            $value = "$value\%";
        } elsif ($op eq 'ends_with') {
            $value = "\%$value";
        }
        if ($escaped) {
            return { $name => { like => \[q{? ESCAPE '\'}, $value] } };
        }
    }
    return {$name => {$sql_op => $value}};
}

sub table { "radius_audit_log" }

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
