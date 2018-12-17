package pf::UnifiedApi::Controller::Config;

=head1 NAME

pf::UnifiedApi::Controller::Config;

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config

=cut

use strict;
use warnings;
use Mojo::Base qw(pf::UnifiedApi::Controller::RestRoute);
use pf::UnifiedApi::OpenAPI::Generator::Config;
use Mojo::Util qw(url_unescape);
use pf::util qw(expand_csv);
use pf::error qw(is_error);

has 'config_store_class';
has 'form_class';
has 'openapi_generator_class' => 'pf::UnifiedApi::OpenAPI::Generator::Config';

sub list {
    my ($self) = @_;
    my $cs = $self->config_store;
    my ($status, $search_info_or_error) = $self->build_list_search_info;
    if (is_error($status)) {
        return $self->render(json => $search_info_or_error, status => $status);
    }

    my $items = $self->do_search($search_info_or_error);
    $self->render(
        json => {
            items  => $items,
            nextCursor => ( @$items + ( $search_info_or_error->{cursor} // 0 ) ),
            prevCursor => ( $search_info_or_error->{cursor} // 0 ),
        }
    );
}

=head2 do_search

do_search

=cut

sub do_search {
    my ($self, $search_info) = @_;
    my $cs = $self->config_store;
    return $cs->filter_offset_limit(
        $search_info->{filter} // sub { 1 },
        $search_info->{cursor},
        $search_info->{limit},
        'id'
    );
}

=head2 build_list_search_info

build_list_search_info

=cut

sub build_list_search_info {
    my ($self) = @_;
    my $params = $self->req->query_params->to_hash;
    my $info = {
        cursor => 0,
        limit => 25,
        filter => sub { 1 },
        (
            map {
                exists $params->{$_}
                  ? ( $_ => $params->{$_} + 0 )
                  : ()
            } qw(limit cursor)
        ),
        (
            map {
                exists $params->{$_}
                  ? ( $_ => [expand_csv($params->{$_})] )
                  : ()
            } qw(sort)
        )
    };
    return 200, $info;
}

sub items {
    my ($self) = @_;
    my $cs = $self->config_store;
    my $items = $cs->readAll('id');
    return [map {$self->cleanup_item($_)} @$items];
}

sub config_store {
    my ($self) = @_;
    $self->config_store_class->new;
}

sub form {
    my ($self, $item) = @_;
    my $parameters = $self->form_parameters($item);
    if (!defined $parameters) {
        $self->render_error(422, "Invalid request");
        return undef;
    }

    $self->form_class->new(@$parameters);
}

sub resource {
    my ($self) = @_;
    my $id = $self->id;
    my $cs = $self->config_store;
    if (!$cs->hasId($id)) {
        return $self->render_error(404, "Item ($id) not found");
    }

    return 1;
}

sub get {
    my ($self) = @_;
    my $item = $self->item;
    if ($item) {
        return $self->render(json => {item => $item}, status => 200);
    }
    return;
}

sub item {
    my ($self) = @_;
    return $self->cleanup_item($self->item_from_store);
}

sub id {
    my ($self) = @_;
    my $primary_key = $self->primary_key;
    my $stash = $self->stash;
    if (exists $stash->{$primary_key}) {
        return url_unescape($stash->{$primary_key});
    }

    return undef;
}

sub item_from_store {
    my ($self) = @_;
    return $self->config_store->read($self->id, 'id')
}

sub cleanup_item {
    my ($self, $item) = @_;
    my $form = $self->form($item);
    if (!defined $form) {
        return undef;
    }

    $form->process($self->form_process_parameters_for_cleanup($item));
    $item = $form->value;
    $item->{not_deletable} = $self->config_store->is_section_in_import($item->{id}) ? $self->json_true : $self->json_false;
    return $item;
}

sub create {
    my ($self) = @_;
    my ($error, $item) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }

    my $id = $item->{id};
    my $cs = $self->config_store;
    if (!defined $id) {
        $self->render_error(422, "Unable to validate", [{ id => "id field is required"}]);
        return 0;
    }

    if ($cs->hasId($id)) {
        return $self->render_error(409, "An attempt to add a duplicate entry was stopped. Entry already exists and should be modified instead of created");
    }

    $item = $self->validate_item($item);
    if (!defined $item) {
        return 0;
    }

    delete $item->{id};
    $cs->create($id, $item);
    $cs->commit;
    $self->res->headers->location($self->make_location_url($id));
    $self->render(status => 201, json => {});
}

sub validate_item {
    my ($self, $item) = @_;
    my $form = $self->form($item);
    if (!defined $form) {
        $self->render_error(422, "Unable to validate invalid no valid formater");
        return undef;
    }

    $form->process($self->form_process_parameters_for_validation($item));
    if (!$form->has_errors) {
        return $form->value;
    }

    $self->render_error(422, "Unable to validate", $self->format_form_errors($form));
    return undef;
}


sub form_process_parameters_for_validation {
    my ($self, $item) = @_;
    return (posted => 1, params => $item);
}

sub form_process_parameters_for_cleanup {
    my ($self, $item) = @_;
    return (init_object => $item);
}

=head2 format_form_errors

format_form_errors

=cut

sub format_form_errors {
    my ($self, $form) = @_;
    my $field_errors = $form->field_errors;
    my @errors;
    while (my ($k,$v) = each %$field_errors) {
        push @errors, {field => $k, message => $v};
    }

    return \@errors;
}

sub make_location_url {
    my ($self, $id) = @_;
    my $url = $self->url_for;
    return "$url/$id";
}

sub remove {
    my ($self) = @_;
    my $id = $self->id;
    my $cs = $self->config_store;
    if (!$cs->remove($id, 'id')) {
        return $self->render_error(422, "Unable to delete $id");
    }

    $cs->commit;
    return $self->render(json => {}, status => 200);
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
    $new_item->{id} = $id;
    $new_data = $self->validate_item($new_item);
    if (!defined $new_data) {
        return;
    }
    delete $new_data->{id};
    my $cs = $self->config_store;
    $cs->update($id, $new_data);
    $cs->commit;
    $self->render(status => 200, json => { message => "$id updated"});
}

sub replace {
    my ($self) = @_;
    my ($error, $item) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }
    my $id = $self->id;
    $item->{id} = $id;
    $item = $self->validate_item($item);
    if (!defined $item) {
        return 0;
    }
    my $cs = $self->config_store;
    delete $item->{id};
    $cs->update($id, $item);
    $cs->commit;
    $self->render(status => 200, json => { message => "$id replaced"});
}

=head2 sort_items

sort items

=cut

sub sort_items {
    my ($self) = @_;
    my ($error, $sort_info) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }

    my $cs = $self->config_store;
    my $items = $sort_info->{items} // [];
    unless ($cs->sortItems($items)) {
        return $self->render_error(422, "Items cannot be resorted in the configuration");
    }

    $cs->commit;
    return $self->render(json => {});
}

sub form_parameters {
    []
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
