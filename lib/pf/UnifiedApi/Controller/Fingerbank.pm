package pf::UnifiedApi::Controller::Fingerbank;

=head1 NAME

pf::UnifiedApi::Controller::Fingerbank -

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Fingerbank

=cut

use strict;
use warnings;
use pf::error qw(is_error is_success);
use pf::util qw(expand_csv);
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use Mojo::Util qw(url_unescape);
use pf::UnifiedApi::Search::Builder::Fingerbank;
use fingerbank::API;

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

=head2 search_builder_class

search_builder_class

=cut

has 'search_builder_class' => "pf::UnifiedApi::Search::Builder::Fingerbank";

sub account_info {
    my ($self) = @_;
    my $api = fingerbank::API->new_from_config;

    my ($status, $account_info) = $api->account_info();
    if(is_success($status)) {
        $self->render(json => $account_info, status => 200);
    }
    else {
        my $msg = $status eq 404 ? "Cannot find Fingerbank account" : $account_info;
        $self->render_error($status, $msg);
    }
}

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

    ($status, my $response) = $self->search_builder->search($search_info_or_error);
    if ( is_error($status) ) {
        return $self->render_error(
            $status,
            $response->{message},
            $response->{errors}
        );
    }

    $response->{items} = [map { $self->cleanup_item($_) } @{$response->{items}}];
    return $self->render(json => $response);
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

    my $model = $self->fingerbank_model;
    my $db = fingerbank::DB_Factory->instantiate(schema => 'Local');
    my $source =  $db->handle->source($model->_parseClassName);
    my %data;
    for my $c ($source->columns) {
        next if !exists $json->{$c};
        $data{$c} = $json->{$c};
    }

    ($status, my $return) = $model->create(\%data);
    if (is_error($status)) {
        return $self->render_error($status, $return);
    }

    my $id = $return->{id};
    my $parent_route = $self->match->endpoint->parent->name;
    my $url = $self->url_for("$parent_route.resource.get", {$self->url_param_name => $id});
    $self->res->headers->location($url);
    return $self->render(json => {id => $id, message => "'$id' created"});
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

    return $self->render(json => {message => "Deleted $id successfully"});
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
    my $scope = $self->stash->{scope};
    my $model = $self->fingerbank_model;
    my $db = fingerbank::DB_Factory->instantiate(schema => 'Local');
    my $source =  $db->handle->source($model->_parseClassName);
    my %args = (
        query => undef,
        model => $model,
        source => $source,
        cursor => $params->{cursor} // 0,
        limit => $params->{limit} // 25,
        with_total_count => $params->{with_total_count} // 0,
        scope => $scope,
        (
            map { $_ => [expand_csv($params->{$_} // '' )] } qw(fields sort)
        ),
    );

    $args{limits}++;
    $args{cursor}+=0;
    return 200, \%args;
}

sub get {
    my ($self) = @_;
    return $self->render(json => { item => $self->cleanup_item($self->item), scope => lc($self->stash->{scope})});
}

=head2 search

search

=cut

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
            $response->{message},
            $response->{errors}
        );
    }

    $response->{items} = [map { $self->cleanup_item($_) } @{$response->{items}}];
    return $self->render(
        json   => $response,
        status => $status
    );
}

sub cleanup_item {
    my ($self, $item) = @_;
    my %new_item;
    while (my ($k, $v) = each %$item) {
        $new_item{$k} = defined $v ? "$v" : undef;
    }

    my $id = $new_item{id};
    $new_item{not_deletable} = $new_item{not_updatable} =  ($id =~ /^L/) ? $self->json_false :  $self->json_true;
    return \%new_item;
}

sub build_search_info {
    my ($self) = @_;
    my ( $status, $data_or_error ) = $self->parse_json;
    if ( is_error($status) ) {
        return $status, $data_or_error;
    }

    my $model = $self->fingerbank_model;
    my $db = fingerbank::DB_Factory->instantiate(schema => 'Local');
    my $source =  $db->handle->source($model->_parseClassName);
    return 200, {
        model => $self->fingerbank_model,
        source => $source,
        scope => $self->stash->{scope},
        (
            map {
                exists $data_or_error->{$_}
                  ? ( $_ => $data_or_error->{$_} )
                  : ()
            } qw(limit query fields sort cursor with_total_count)
        )
    };
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

sub search_builder {
    my ($self) = @_;
    return $self->search_builder_class->new();
}

sub update {
    my ($self) = @_;
    my ($error, $new_data) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }

    my $old_item = $self->item;
    my $new_item = {%$old_item, %$new_data};

    my $id = $self->id;
    my ($status, $message) = $self->fingerbank_model->update($id, $new_item);
    if (is_error($status)) {
        $self->render_error($status, $message);
    }

    $self->render(status => 200, json => { message => "$id updated"});
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
