package pf::UnifiedApi::Controller::Fingerbank;

=head1 NAME

pf::UnifiedApi::Controller::Fingerbank -

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Fingerbank

=cut

use strict;
use warnings;
use pf::error qw(is_error);
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use Mojo::Util qw(url_unescape);

=head2 url_param_name

The name of the url parameter to get the value of the resource identifier

=cut

has 'url_param_name';

=head2 primary_key

The name of the primary key in the data base

=cut

has 'primary_key';


=head2 fingerbank_model

fingerbank_model

=cut

has 'fingerbank_model';

sub resource {
    my ($self) = @_;
    my $id = $self->stash($self->url_param_name);
    my $model = $self->fingerbank_model;
    my ($status, $item ) = $model->read_hashref($id);
    if (is_error($status)) {
        return $self->render_error($status, $item);
    }

    push @{$self->stash->{item}}, $item;
    return 1;
}

=head2 list

list

=cut

sub list {
    my ($self) = @_;
    my ($status, $search_info_or_error) = $self->build_list_search_info;
    if (is_error($status)) {
        return $self->render(json => $search_info_or_error, status => $status);
    }

    ($status, my $items) = $self->items($search_info_or_error);
    if (is_error($status)) {
        return $self->render_error($status, $items);
    }

    my ($offset, $limit, $with_total_count) = @{$search_info_or_error}{qw(offset nb_of_rows with_total_count)};
    my $nextCursor;
    if (@$items == $limit) {
        pop @$items;
        $nextCursor = $offset + $limit - 1;
    }

    my $count;
    if ($with_total_count) {
        $count = $self->fingerbank_model->count;
    }

    return $self->render(json => {
        items => $items,
        scope => $self->stash->{scope},
        prevCursor => $offset,
        ( defined $nextCursor ? ( nextCursor => $nextCursor ) : () ),
        ( defined $count ? ( total_count => $count ) : () ),
    });
}

=head2 create

create

=cut

sub create {
    my ($self) = @_;
    my ($status, $json) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $json, status => $status);
    }

    ($status, my $return) = $self->fingerbank_model->create($json);
    if (is_error($status)) {
        return $self->render_error($status, $return);
    }

    my $parent_route = $self->match->endpoint->parent->name;
    my $url = $self->url_for("$parent_route.resource.get", {$self->url_param_name => $return->{id}});
    $self->res->headers->location($url);
    return $self->render(json => {});
}

=head2 remove

remove

=cut

sub remove {
    my ($self) = @_;
    my $id = $self->id;
    my ($status, $msg) = $self->fingerbank_model->delete($id);
    if (is_error($status)) {
        return $self->render_error($status, $msg);
    }

    return $self->render(json => {});;
}

=head2 id

Get id of current resource

=cut

sub id {
    my ($self) = @_;
    url_unescape($self->stash->{$self->url_param_name});
}

sub build_list_search_info {
    my ($self) = @_;
    my $params = $self->req->query_params->to_hash;
    my %args = (
        offset => $params->{cursor} // 0,
        nb_of_rows => $params->{limit} // 25,
        order_by => 'id',
        order => 'asc',
        with_total_count => $params->{with_total_count} // 0,
        schema => $self->stash->{scope},
    );
    $args{nb_of_rows}++;

    return 200, \%args;
}

=head2 items

items

=cut

sub items {
    my ($self, $params) = @_;
    my $model = $self->fingerbank_model;
    return $model->list_paginated($params);
}

sub get {
    my ($self) = @_;
    return $self->render(json => { item => $self->item, scope => $self->stash->{scope}});
}

=head2 search

search

=cut

sub search {
    my ($self) = @_;
    my $scope = $self->stash->{scope};
    return $self->render(json => { items => [], scope => $scope});
}

=head2 query_to_sql_abstract

query_to_sql_abstract

=cut

sub query_to_sql_abstract {
    my ($self) = @_;
    return ;
}

=head2 item

item

=cut

sub item {
    my ($self) = @_;
    my $stash = $self->stash;
    return ${$stash->{item}}[-1];
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
