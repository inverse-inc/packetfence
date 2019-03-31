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
use pf::UnifiedApi::GenerateSpec;
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
    $items = [map {$self->cleanup_item($_)} @$items];
    $self->render(
        json => {
            items  => $items,
            nextCursor => ( @$items + ( $search_info_or_error->{cursor} // 0 ) ),
            prevCursor => ( $search_info_or_error->{cursor} // 0 ),
        },
        status => 200,
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

=head2 items

items

=cut

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
    my ($self, $item, @args) = @_;
    my $parameters = $self->form_parameters($item);
    if (!defined $parameters) {
        return 422, "Invalid requests";
    }

    my $form = $self->form_class->new(@$parameters, @args);
    return 200, $form;
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
    my $id = $item->{id};
    my ($status, $form) = $self->form($item);
    if (is_error($status)) {
        return undef;
    }

    $form->process($self->form_process_parameters_for_cleanup($item));
    $item = $form->value;
    $item->{not_deletable} = $self->config_store->is_section_in_import($id) ? $self->json_true : $self->json_false;
    $item->{id} = $id;
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
    my ($status, $form) = $self->form($item);
    if (is_error($status)) {
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

=head2 options

Handle the OPTIONS HTTP method

=cut

sub options {
    my ($self) = @_;
    my ($status, $form) = $self->form;
    if (is_error($status)) {
        return $self->render_error($status, $form);
    }

    return $self->render(json => $self->options_from_form($form));
}

=head2 options_from_form

Get the options from the form

=cut

sub options_from_form {
    my ($self, $form) = @_;
    my %meta;
    my %output = (
        meta => \%meta,
    );

    my $defaultValues = $self->default_values;
    for my $field ($form->fields) {
        next if $field->inactive;
        my $name = $field->name;
        $meta{$name} = $self->field_meta($field);
    }

    return \%output;
}

=head2 field_meta

Get a field's meta data

=cut

sub field_meta {
    my ($self, $field, $no_array) = @_;
    my $type = $self->field_type($field, $no_array);
    my $meta = {
        type        => $type,
        required    => $self->field_is_required($field),
        placeholder => $self->field_placeholder($field),
        default     => $self->field_default($field),
        $self->field_extra_meta($field, $type),
    };

    if ($type ne 'array' && $type ne 'object') {
        if (!defined ($meta->{allowed}  = $self->field_allowed($field))) {
            $meta->{allowed_lookup} = $self->field_allowed_lookup($field);
        }
    }

    return $meta;
}

=head2 field_extra_meta

Get the extra meta data for a field

=cut

sub field_extra_meta {
    my ($self, $field, $type) = @_;
    my %extra;
    if ($type eq 'array') {
        $extra{item} = $self->field_meta_array_items($field, 1);
    } elsif ($type eq 'object') {
        $extra{properties} = $self->field_meta_object_properties($field);
    } else {
        if ($field->isa("HTML::FormHandler::Field::Text")) {
            $self->field_text_meta($field, \%extra);
        }

        if ($field->isa("HTML::FormHandler::Field::Integer") || $field->isa("HTML::FormHandler::Field::IntRange")) {
            $self->field_integer_meta($field, \%extra);
        }
    }

    return %extra;
}

=head2 field_meta_object_properties

Get the properties of a field

=cut

sub field_meta_object_properties {
    my ($self, $field) = @_;
    my %p;
    for my $f ($field->fields) {
        $p{$f->name} = $self->field_meta($f);
    }

    return \%p;
}

=head2 field_integer_meta

Update integer field meta data

=cut

sub field_integer_meta {
    my ($self, $field, $extra) = @_;
    my $min = $field->range_start;
    my $max = $field->range_end;
    if (defined $min) {
        $extra->{min_value} = $min;
    } elsif ($field->isa("HTML::FormHandler::Field::PosInteger")) {
        $extra->{min_value} = 0;
    }

    if (defined $max) {
        $extra->{max_value} = $max;
    }

    return ;
}

=head2 field_text_meta

Update text field meta data

=cut

sub field_text_meta {
    my ($self, $field, $extra) = @_;
    my $min = $field->minlength;
    my $max = $field->maxlength;
    if ($min) {
        $extra->{min_length} = $min;
    }

    if (defined $max) {
        $extra->{max_length} = $max;
    }

    my $pattern = $field->get_tag("option_pattern");
    if ($pattern) {
        $extra->{pattern} = $pattern;
    }

    return ;
}

=head2 field_type

Find the field type

=cut

sub field_type {
    my ($self, $field, $no_array) = @_;
    return pf::UnifiedApi::GenerateSpec::fieldType($field, $no_array);
}

=head2 field_is_required

Check if the field is required

=cut

sub field_is_required {
    my ($self, $field) = @_;
    return  $field->required ? $self->json_true() : $self->json_false();
}

=head2 resource_options

Create the resource options

=cut

sub resource_options {
    my ($self) = @_;
    my ($status, $form) = $self->form($self->item);
    if (is_error($status)) {
        return $self->render_error($status, $form);
    }

    my (%defaults, %placeholders, %allowed, %meta);
    my %output = (
        meta => \%meta,
    );
    my $inheritedValues = $self->resourceInheritedValues;
    my $defaultValues = $self->default_values;
    for my $field ($form->fields) {
        my $name = $field->name;
        next if $self->isResourceFieldSkippable($field);
        $meta{$name} = $self->field_meta($field);
    }

    return $self->render(json => \%output);
}

=head2 isResourceFieldSkippable

Check if a Resource Field is Skippable

=cut

sub isResourceFieldSkippable {
    my ($self, $field) = @_;
    return $field->name eq 'id';
}

=head2 resourceInheritedValues

Get the resource inherited values

=cut

sub resourceInheritedValues {
    my ($self) = @_;
    my $values = $self->config_store->readFromImported($self->id, 'id');
    if ($values) {
        $values = $self->cleanup_item($values);
    }

    return $values;
}

=head2 field_default

Get the default value of a field

=cut

sub field_default {
    my ($self, $field, $inheritedValues) = @_;
    return $field->default // $inheritedValues ? $inheritedValues->{$field->name} : undef;
}

=head2 default_values

Get the default values from the config section

=cut

sub default_values {
    my ($self) = @_;
    my $cs = $self->config_store;
    my $default_section = $cs->default_section;
    my $defaultValues;
    if ($default_section) {
        $defaultValues = $self->cleanup_item($cs->read($default_section, 'id'));
    }

    return $defaultValues;
}

=head2 field_placeholder

Get the placeholder for the field

=cut

sub field_placeholder {
    my ($self, $field) = @_;
    my $name = $field->name;
    my $cs = $self->config_store;
    my $default_section = $cs->default_section;
    my $value;
    if ($default_section) {
        my $item = $self->cleanup_item($cs->read($default_section, 'id'));
        $value = $item->{$name};
    }

    if (!defined $value ) {
        my $element_attr = $field->element_attr // {};
        $value = $element_attr->{placeholder}
    };

    if (!defined $value) {
        $value = $field->get_tag('defaults');
        if ($value eq '') {
            $value = undef;
        }
    }

    return $value;
}

=head2 field_meta_array_items

Get the meta for the items of the array

=cut

sub field_meta_array_items {
    my ($self, $field) = @_;
    if ($field->isa('HTML::FormHandler::Field::Repeatable')) {
        $field->init_state;
        my $element = $field->clone_element($field->name . "_temp");
        if ($element->isa('HTML::FormHandler::Field::Select') ) {
            $element->_load_options();
        }

        return $self->field_meta($element);
    }

    return $self->field_meta($field, 1);
}

=head2 field_resource_placeholder

The place holder for the field

=cut

sub field_resource_placeholder {
    my ($self, $field, $inherited_values) = @_;
    my $name = $field->name;
    my $value;
    if ($inherited_values) {
        $value = $inherited_values->{$name};
    }

    if (!defined $value) {
        my $element_attr = $field->element_attr // {};
        $value = $element_attr->{$name};
    }

    return $value;
}

=head2 field_allowed

The allowed fields

=cut

sub field_allowed {
    my ($self, $field) = @_;
    if ($field->isa("pfappserver::Form::Field::FingerbankSelect") || $field->isa("pfappserver::Form::Field::FingerbankField")) {
        return undef;
    }

    my $allowed  = $field->get_tag("options_allowed") || undef;

    if (!defined $allowed) {
        if ($field->isa('HTML::FormHandler::Field::Select')) {
            $field->_load_options;
            $allowed = $field->options;
        }

        if ($field->isa('HTML::FormHandler::Field::Repeatable')) {
            $field->init_state;
            my $element = $field->clone_element($field->name . "_temp");
            if ($element->isa('HTML::FormHandler::Field::Select') ) {
                $element->_load_options();
                $allowed = $element->options;
            }
        }
    }

    if ($allowed) {
        $allowed = $self->map_options($allowed);
    }

    return $allowed;
}

=head2 field_allowed_lookup

field_allowed_lookup

=cut

my %FB_MODEL_2_PATH = (
    Combination       => 'combinations',
    Device            => 'devices',
    DHCP6_Enterprise  => 'dhcp6_enterprises',
    DHCP6_Fingerprint => 'dhcp6_fingerprints',
    DHCP_Fingerprint  => 'dhcp_fingerprints',
    DHCP_Vendor       => 'dhcp_vendors',
    MAC_Vendor        => 'mac_vendors',
    User_Agent        => 'user_agents',
);

sub field_allowed_lookup {
    my ($self, $field) = @_;
    if ($field->isa("pfappserver::Form::Field::FingerbankSelect") || $field->isa("pfappserver::Form::Field::FingerbankField")) {
        my $fingerbank_model = $field->fingerbank_model;
        my $name = $fingerbank_model->_parseClassName;
        my $path = $FB_MODEL_2_PATH{$name};
        return {
            search_path => "/api/v1/fingerbank/local/$path/search",
            field_name  => $fingerbank_model->value_field
        };
    }

    return undef;
}

=head2 map_options

map_options

=cut

sub map_options {
    my ($self, $options) = @_;
    return [ map { $self->map_option($_) } @$options ];
}

=head2 map_option

map_option

=cut

sub map_option {
    my ($self, $option) = @_;
    my %hash = %$option;
    if (exists $hash{value} && defined $hash{value} && $hash{value} eq '') {
        return;
    }

    if (exists $hash{label}) {
        $hash{text} = (delete $hash{label} // '') . "";
    }

    if (exists $hash{options}) {
       $hash{options} = $self->map_options($hash{options});
    }

    return \%hash;
}

=head2 form_parameters

The form parameters should be overridded

=cut

sub form_parameters {
    []
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
