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
use pf::util qw(expand_csv);
use Mojo::Util qw(url_unescape);
use pf::UnifiedApi::Search::Builder;
use pf::UnifiedApi::OpenAPI::Generator::Crud;

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

=head2 url_parent_ids

url_parent_ids

=cut

has 'url_parent_ids' => sub { [] };


=head2 search_builder_class

search_builder_class

=cut

has 'search_builder_class' => "pf::UnifiedApi::Search::Builder";

=head2 openapi_generator_class

openapi_generator_class

=cut

has 'openapi_generator_class' => 'pf::UnifiedApi::OpenAPI::Generator::Crud';

=head1 METHODS

=cut

sub list {
    my ($self) = @_;
    my ($status, $search_info_or_error) = $self->build_list_search_info;
    if (is_error($status)) {
        return $self->render(json => $search_info_or_error, status => $status);
    }

    ($status, my $response) = $self->search_builder->search($search_info_or_error);
    if ( is_error($status) ) {
        return $self->render_error(
            $status,
            $response->{msg},
            $response->{errors}
        );
    }

    return $self->render(
        json   => $response,
        status => $status
    );
}

sub build_list_search_info {
    my ($self) = @_;
    my $params = $self->req->query_params->to_hash;

    return 200, {
        dal => $self->dal,
        query => $self->build_list_search_query,
        (
            map {
                exists $params->{$_}
                  ? ( $_ => $params->{$_} )
                  : ()
            } qw(limit cursor with_total_count)
        ),
        (
            map {
                exists $params->{$_}
                  ? ( $_ => [expand_csv($params->{$_})] )
                  : ()
            } qw(fields sort)
        )
    };
}

sub build_list_search_query {
    my ($self) = @_;
    my $parent_data = $self->parent_data;
    if (keys %$parent_data == 0) {
        return undef;
    }

    my $query;
    my @sub_queries;
    while (my ($k, $v) = each %$parent_data) {
        next if !defined $v || ref $v;
        push @sub_queries, { field => $k, op => 'equals', value => $v };
    }

    if (@sub_queries) {
        $query = {
            values => \@sub_queries,
            op => 'and',
        }
    }

    return $query;
}

sub where_for_list {
    my ($self) = @_;
    $self->parent_data;
}

sub search_builder {
    my ($self) = @_;
    return $self->search_builder_class->new();
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
    return $self->render(json => { item => $self->item }, status => $stash->{status});
}

=head2 item

item

=cut

sub item {
    my ($self) = @_;
    my $stash = $self->stash;
    return ${$stash->{item}}[-1];
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

=head2 id

Get id of current resource

=cut

sub id {
    my ($self) = @_;
    url_unescape($self->stash->{$self->url_param_name});
}

sub create_error_msg {
    "Unable to create resource"
}

sub render_create {
    my ($self, $status, $obj) = @_;
    if (is_error($status)) {
        return $self->render_error($status, $self->create_error_msg($obj));
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
    my $data = $self->req->json;
    my %update;
    for my $field (@{$self->dal->table_field_names}) {
        next if !exists $data->{$field};
        $update{$field} = $data->{$field};
    }

    return \%update;
}

sub replace {
    my ($self) = @_;
    return $self->update;
}

sub search {
    my ($self) = @_;
    my ($status, $search_info_or_error) = $self->build_search_info;
    if (is_error($status)) {
        return $self->render(json => $search_info_or_error, status => $status);
    }

    ($status, my $response) = $self->search_builder->search($search_info_or_error);
    if ( is_error($status) ) {
        return $self->render_error(
            $status,
            $response->{msg},
            $response->{errors}
        );
    }

    return $self->render(
        json   => $response,
        status => $status
    );
}

sub build_search_info {
    my ($self) = @_;
    my ( $status, $data_or_error ) = $self->parse_json;
    if ( is_error($status) ) {
        return $status, $data_or_error;
    }

    return 200, {
        dal => $self->dal,
        (
            map {
                exists $data_or_error->{$_}
                  ? ( $_ => $data_or_error->{$_} )
                  : ()
            } qw(limit query fields sort cursor with_total_count)
        )
    };
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
