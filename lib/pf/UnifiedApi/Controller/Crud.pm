package pf::UnifiedApi::Controller::Crud;

=head1 NAME

pf::UnifiedApi::Controller::Crud -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Crud

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use Mojo::JSON qw(decode_json);
use pf::error qw(is_error);
use pf::log;
use pf::UnifiedApi::Search;

our %OP_HAS_SUBQUERIES = (
    'and' => 1,
    'or' => 1,
);


=head1 ATTRIBUTES

=cut

has 'dal';

=head2 url_param_name

The name of the url parameter to get the value of the resource identifier

=cut

has 'url_param_name';

=head2 primary_key

The name of the primary key in the data base

=cut

has 'primary_key' => 'id';

=head2 parent_primary_key_map

The map of the url parameters to the parent database field name.

Example:

    {
        user_id => 'pid',
    }

=cut

has 'parent_primary_key_map' => sub { {} };

=head1 METHODS

=cut

sub list {
    my ($self) = @_;
    my $number_of_results = $self->list_number_of_results;
    my $limit = $number_of_results + 1;
    my $cursor = $self->list_cursor();
    my ($status, $iter) = $self->dal->search(
        -limit => $limit,
        -offset => $cursor,
        -with_class => undef,
        -where => $self->where_for_list,
    );
    my $items = $iter->all;
    my $prevCursor = $cursor - $number_of_results;
    my %results = (
        items => $items,
    );
    if (@$items == $limit) {
        pop @$items;
        $results{nextCursor} = $cursor + $number_of_results
    }
    if ($prevCursor >= 0 ) {
        $results{prevCursor} = $prevCursor;
    }
    $self->render(json => \%results, status => $status);
}

sub where_for_list {
    my ($self) = @_;
    $self->parent_data;
}

sub list_cursor {
    my ($self) = @_;
    my $cursor = $self->req->param('cursor') // 0;
    $cursor += 0;
    if ($cursor < 0) {
        $cursor = 0;
    }
    return $cursor;
}

sub list_number_of_results {
    return 100;
}

sub resource {
    my ($self) = @_;
    my ($status, $item) = $self->do_get($self->get_lookup_info);
    if (is_error($status)) {
        return $self->render_error($status, "Unable to get resource with this identifier");
    }
    push @{$self->stash->{item}}, $item;
    $self->stash->{status} = $status;
    return 1;
}

sub get {
    my ($self) = @_;
    return $self->render_get();
}

sub get_lookup_info {
    my ($self) = @_;
    $self->build_item_lookup;
}

sub render_get {
    my ($self) = @_;
    my $stash = $self->stash;
    return $self->render(json => { item => ${$stash->{item}}[-1], status => $stash->{status}});
}

sub do_get {
    my ($self, $data) = @_;
    my ($status, $item) = $self->dal->find($data);
    return ($status, is_error($status) ? undef : $item->to_hash());
}

sub build_item_lookup {
    my ($self) = @_;
    my $lookup = $self->parent_data;
    $lookup->{$self->primary_key} = $self->stash($self->url_param_name);
    return $lookup;
}

sub create {
    my ($self) = @_;
    return $self->render_create(
        $self->do_create($self->make_create_data())
    );
}

sub render_create {
    my ($self, $status, $obj) = @_;
    if (is_error($status)) {
        return $self->render_error($status, "Unable to create resource");
    }
    $self->res->headers->location($self->make_location_url($obj));
    return $self->render(text => '', status => $status);
}

sub make_location_url {
    my ($self, $obj) = @_;
    my $parent_route = $self->match->endpoint->parent->name;
    my $url = $self->url_for("$parent_route.get", {$self->url_param_name => $obj->{$self->primary_key}});
    return "$url";
}

sub make_create_data {
    my ($self) = @_;
    my ($status, $json) = $self->parse_json;
    if (is_error($status)) {
        return ($status, $json);
    }
    my $parent_data = $self->parent_data;
    @{$json}{keys %$parent_data} = values %$parent_data;
    return ($status, $json);
}

sub parent_data {
    my ($self) = @_;
    my $map = $self->parent_primary_key_map;
    my %data;
    my $captures = $self->stash->{'mojo.captures'};
    while (my ($param_name, $field_name) = each %$map) {
        $data{$field_name} = $captures->{$param_name};
    }

    return \%data;
}

sub do_create {
    my ($self, $status, $data) = @_;
    if (is_error($status)) {
       return ($status, $data);
    }
    return $self->create_obj($data);
}

sub create_obj {
    my ($self, $data) = @_;
    my $obj = $self->dal->new($data);
    my $status = $obj->insert;
    if (is_error($status)) {
        return ($status, {message => $self->status_to_error_msg($status)});
    }
    return ($status, $obj);
}

sub remove {
    my ($self) = @_;
    return $self->render_remove(
        $self->do_remove()
    );
}

sub render_remove {
    my ($self, $status) = @_;
    if (is_error($status)) {
        return $self->render_error($status, "Unable to remove resource");
    }
    return $self->render(json => {}, status => $status);
}

sub do_remove {
    my ($self) = @_;
    return $self->dal->remove_by_id($self->build_item_lookup);
}

=head2 update

update

=cut

sub update {
    my ($self) = @_;
    my $req = $self->req;
    my $res = $self->res;
    my $data = $self->update_data;
    my ($status, $count) = $self->dal->update_items(
        -where => $self->build_item_lookup,
        -set => {
            %$data,
        },
        -limit => 1,
    );
    if ($count == 0) {
        $status = 404;
    }
    $res->code($status);
    if ($res->is_error) {

    }
    return $self->render(json => {});
}

sub update_data {
    my ($self) = @_;
    return $self->req->json;
}

sub replace {
    my ($self) = @_;
    return $self->update;
}

sub search {
    my ($self) = @_;
    my ($status, $query_info) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $query_info, status => $status);
    }

    my $where = $self->make_where($query_info);

    if (!defined $where) {
        return;
    }

    my $offset = $self->make_offset($query_info);
    my $limit = $self->make_limit($query_info);
    my $order_by = $self->make_order_by($query_info);

    my %search_args = (
        -with_class => undef,
        -where => $where,
        -limit => $limit,
        -offset => $offset,
        -order_by => $order_by,
    );

    my $columns = $self->make_columns($query_info);
    if (!defined $columns) {
        return;
    }

    if (@$columns) {
        $search_args{'-columns'} = $columns;
    }

    ($status, my $iter) = $self->dal->search(
        %search_args
    );

    if (is_error($status)) {
        return $self->render_error($status, "Error fulfilling search");
    }

    my $items = $iter->all();
    my $nextCursor = undef;
    if (@$items == $limit) {
        pop @$items;
        $nextCursor = $offset + $limit - 1;
    }

    return $self->render(
        json   => {
            prevCursor => $offset,
            items => $items,
            (
                defined $nextCursor ? (nextCursor => $nextCursor) : ()
            )
        },
        status => $status
    );
}

sub make_offset {
    my ($self, $query) = @_;
    my $cursor =  $self->req->query_params->param('cursor') || '0';
    return int( $cursor);
}

sub make_limit {
    my ($self, $q) = @_;
    my $limit = int($q->{limit} // 0) || 25;
    $limit++;
    return $limit;
}

sub make_columns {
    my ( $self, $q ) = @_;
    my $cols = $q->{fields} // [];
    my @invalid = grep { !$self->valid_column($_) } @$cols;

    if (@invalid) {
        $self->render_error(
            422,
            "Invalid column(s) defined",
            [ map { { msg => "$_ is an invalid column" } } @invalid ]
        );
        return undef;
    }

    return $cols;
}

sub valid_column {
    my ($self, $col) = @_;
    my $meta = $self->dal->get_meta;
    return exists $meta->{$col};
}

sub verify_query {
    my ($self, $query) = @_;
    my $op = $query->{op} // '(null)';
    if (!$self->is_valid_op($query)) {
        return (422, "$op is not valid");
    }

    if ($OP_HAS_SUBQUERIES{$op}) {
        for my $q (@{$query->{values} // []}) {
            my ($status, $query) = $self->verify_query($q);
            if (is_error($status)) {
                return ($status, $query);
            }
        }
    } else {
        my $status = $self->validate_field($query);
        if (is_error($status)) {
            return ($status, "$query->{field} is an invalid field");
        }
    }

    return (200, $query);
}

sub validate_field {
    my ($self, $q) = @_;
    return $self->dal->validate_field($q->{field}, $q->{value});
}

sub is_valid_op {
    my ($self, $q) = @_;
    return pf::UnifiedApi::Search::valid_op($q->{op});
}

sub make_where {
    my ($self, $query_info) = @_;
    my $query = $query_info->{query};
    if (!defined $query) {
        return {};
    }

    (my $status, $query) = $self->verify_query($query);
    if (is_error($status)) {
        $self->render_error($status, $query);
        return undef;
    }

    my $where = pf::UnifiedApi::Search::searchQueryToSqlAbstract($query);
    return $where;
}

sub make_order_by {
    my ($self, $q) = @_;
    my $sort = $q->{sort} // [];
    local $_;
    return [map { normalize_sort($_)  } @$sort ];
}

sub normalize_sort {
    my ($order_by) = @_;
    my $direction = '-asc';
    if ($order_by =~ /^([^ ]+) (DESC|ASC)$/ ) {
       $order_by = $1;
       $direction = "-" . lc($2);
    }
    return { $direction => $order_by }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

