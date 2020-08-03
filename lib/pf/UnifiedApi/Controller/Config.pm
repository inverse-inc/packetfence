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
use pf::constants;
use List::MoreUtils qw(any);
use pf::UnifiedApi::OpenAPI::Generator::Config;
use pf::UnifiedApi::GenerateSpec;
use Mojo::JSON qw(encode_json);
use pf::util qw(expand_csv isenabled);
use pf::error qw(is_error);
use pf::error qw(is_error is_success);
use pf::pfcmd::checkup ();
use pf::UnifiedApi::Search::Builder::Config;
use pf::condition_parser qw(parse_condition_string ast_to_object);

has 'config_store_class';
has 'form_class';
has 'openapi_generator_class' => 'pf::UnifiedApi::OpenAPI::Generator::Config';
has 'search_builder_class' => "pf::UnifiedApi::Search::Builder::Config";

our %FORMS;

sub search {
    my ($self) = @_;
    my ($status, $search_info_or_error) = $self->build_search_info;
    if (is_error($status)) {
        return $self->render(json => $search_info_or_error, status => $status);
    }

    return $self->handle_search($search_info_or_error);
}

sub handle_search {
    my ($self, $search_info) = @_;
    my ($status, $response) = $self->search_builder->search($search_info);
    if ( is_error($status) ) {
        return $self->render_error(
            $status,
            $response->{message},
            $response->{errors}
        );
    }

    unless ($search_info->{raw}) {
        $response->{items} = $self->cleanup_items($response->{items} // []);
    }

    my $fields = $search_info->{fields};
    if (defined $fields && @$fields) {
        $self->remove_fields($fields, $response->{items});
    }

    return $self->render(
        json   => $response,
        status => $status
    );
}

=head2 build_search_info

build_search_info

=cut

sub build_search_info {
    my ($self) = @_;
    my ($status, $data_or_error) = $self->parse_json;
    if (is_error($status)) {
        return $status, $data_or_error;
    }

    my %search_info = (
        configStore => $self->config_store,
        (
            map {
                exists $data_or_error->{$_}
                  ? ( $_ => $data_or_error->{$_} )
                  : ()
            } qw(limit query fields sort cursor with_total_count raw)
        )
    );

    $search_info{sort} = $self->normalize_sort_specs($search_info{sort});
    return 200, \%search_info;
}

sub normalize_sort_specs {
    my ($self, $sort) = @_;
    return [
        map {
            my $sort_spec = $_;
            my $dir       = 'asc';
            my $s         = $sort_spec;
            if ($s =~ s/  *(DESC|ASC)$//i) {
                $dir = lc($1);
            }

            { field => $s, dir => $dir }
        } @{ $sort // [] }
    ];
}

sub search_builder {
    my ($self) = @_;
    return $self->search_builder_class->new();
}

sub list {
    my ($self) = @_;
    my ($status, $search_info_or_error) = $self->build_list_search_info;
    if (is_error($status)) {
        return $self->render(json => $search_info_or_error, status => $status);
    }

    return $self->handle_search($search_info_or_error);
}

=head2 cleanup_items

cleanup_items

=cut

sub cleanup_items {
    my ($self, $items) = @_;
    return [grep { $self->item_shown($_) } map {$self->cleanup_item($_, $self->cached_form($_)) } @$items];
}

sub item_shown { 1 }

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

=head2 remove_fields

remove_fields

=cut

sub remove_fields {
    my ($self, $fields, $items) = @_;
    my $count = @$items;
    for (my $i =0;$i<$count;$i++) {
        my %new_item;
        @new_item{@$fields} = @{$items->[$i]}{@$fields};
        $items->[$i] = \%new_item;
    }
}

=head2 build_list_search_info

build_list_search_info

=cut

sub build_list_search_info {
    my ($self) = @_;
    my $params = $self->req->query_params->to_hash;
    my %search_info = (
        configStore => $self->config_store,
        cursor => 0,
        limit => 25,
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
            } qw(sort fields)
        ),
        (
            map {
                $_ => isenabled($params->{$_})
            } qw(raw)
        )
    );
    $search_info{sort} = $self->normalize_sort_specs($search_info{sort});
    return 200, \%search_info;
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

    my $form = $self->form_class->new(@$parameters, @args, user_roles => $self->stash->{'admin_roles'});
    return 200, $form;
}

sub cached_form_key {
    my ($self, $item, @args) = @_;
    return $self->form_class;
}

sub cached_form {
    my ($self, $item, @args) = @_;
    my $cached_form_key = $self->cached_form_key($item, @args);
    if (defined $cached_form_key) {
        if ($FORMS{$cached_form_key}){
            my $form = $FORMS{$cached_form_key};
            $self->reset_form($form, $item, @args);
            return $form;
        }
    }

    my ($status, $form) = $self->form($item, @args);
    if (is_error($status)) {
        return undef;
    }

    if (defined $cached_form_key) {
        $FORMS{$cached_form_key} = $form;
    }

    return $form;
}

=head2 reset_form

reset_form

=cut

sub reset_form {
    my ($self, $form, $item, @args) = @_;
    $form->clear_fields;
    my %all_args = (
        @{$self->form_parameters($item)},
        @args,
        user_roles => $self->stash->{'admin_roles'}
    );
    while (my ($k, $v) = each %all_args) {
        if ($form->can($k)) {
            $form->$k($v);
        }
    }
    $form->_build_fields;
    return;
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
    return $self->render_error(500, "Unknown error getting item");;
}

sub item {
    my ($self, $id) = @_;
    my $skip_inheritance = isenabled($self->req->param('skip_inheritance'));
    return $self->cleanup_item($self->item_from_store($id, $skip_inheritance));
}

sub id {
    my ($self) = @_;
    my $primary_key = $self->primary_key;
    my $stash = $self->stash;
    if (exists $stash->{$primary_key}) {
        return $stash->{$primary_key};
    }

    return undef;
}

sub item_from_store {
    my ($self, $id, $skip_inheritance) = @_;
    if ($skip_inheritance) {
        return $self->config_store->readWithoutInherited($id // $self->id, 'id')
    } else {
        return $self->config_store->read($id // $self->id, 'id')
    }
}

sub cleanup_item {
    my ($self, $item, $form) = @_;
    my $id = $item->{id};
    if (!defined $form) {
        (my $status, $form) = $self->form($item);
        if (is_error($status)) {
            return undef;
        }
    }

    my $cs = $self->config_store;
    $form->process($self->form_process_parameters_for_cleanup($item));
    $item = $form->value;
    $item->{not_deletable} = $cs->is_section_in_import($id) ? $self->json_true : $self->json_false;
    $item->{not_sortable} = $self->is_sortable($cs, $id, $item);
    $item->{id} = $id;
    return $item;
}

sub is_sortable {
    my ($self, $cs, $id, $item) = @_;
    my $default_section = $cs->default_section;
    return (defined($cs->default_section) && $id eq $default_section) ? $self->json_true : $self->json_false;
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
        $self->render_error(422, "Unable to validate", [{ message => "id field is required", field => 'id'}]);
        return 0;
    }

    if ($cs->hasId($id)) {
        return $self->render_error(409, "An attempt to add a duplicate entry was stopped. Entry already exists and should be modified instead of created");
    }

    (my $status, $item) = $self->validate_item($item);
    if (is_error($status)) {
        return $self->render(status => $status, json => $item);
    }

    delete $item->{id};
    $cs->create($id, $item);
    return unless($self->commit($cs));
    $self->stash( $self->primary_key => $id );
    $self->res->headers->location($self->make_location_url($id));
    $self->render(status => 201, json => $self->create_response($id));
}

sub create_response {
    my ($self, $id) = @_;
    return { id => $id, message => "'$id' created" };
}

sub commit {
    my ($self, $cs) = @_;
    my ($res, $msg) = $cs->commit();
    unless($res) {
        $self->render_error(500, $msg);
        return undef;
    }
    return $TRUE;
}

sub validate_item {
    my ($self, $item) = @_;
    my ($status, $form) = $self->form($item);
    if (is_error($status)) {
        return $status, { message => $form };
    }

    $form->process($self->form_process_parameters_for_validation($item));
    if (!$form->has_errors) {
        return 200, $form->value;
    }

    return 422, { message => "Unable to validate", errors => $self->format_form_errors($form) };
}


sub form_process_parameters_for_validation {
    my ($self, $item) = @_;
    return (posted => 1, params => $item);
}

sub form_process_parameters_for_cleanup {
    my ($self, $item) = @_;
    return (init_object => $item, posted => 0);
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

sub can_delete {
    return (200, '');
}

sub remove {
    my ($self) = @_;
    my ($status, $msg) = $self->can_delete();
    if (is_error($status)) {
        return $self->render_error($status, $msg);
    }

    my $id = $self->id;
    my $cs = $self->config_store;
    ($msg, my $deleted) = $cs->remove($id, 'id');
    if (!$deleted) {
        return $self->render_error(422, "Unable to delete $id - $msg");
    }

    return unless($self->commit($cs));
    return $self->render(json => {message => "Deleted $id successfully"}, status => 200);
}

sub update {
    my ($self) = @_;
    my ($error, $data) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }
    my $old_item = $self->item;
    my $new_item = {%$old_item, %$data};
    my $id = $self->id;
    $new_item->{id} = $id;
    delete $new_item->{not_deletable};
    my ($status, $new_data) = $self->validate_item($new_item);
    if (is_error($status)) {
        return $self->render(status => $status, json => $new_data);
    }

    delete $new_data->{id};
    my $cs = $self->config_store;
    $self->cleanupItemForUpdate($old_item, $new_data, $data);
    $cs->update($id, $new_data);
    return unless($self->commit($cs));
    $self->render(status => 200, json => { message => "Settings updated"});
}

=head2 cleanupItemForUpdate

cleanupItemForUpdate

=cut

sub cleanupItemForUpdate {
    my ($self, $old_item, $new_data, $data) = @_;
    return;
}

sub replace {
    my ($self) = @_;
    my ($error, $item) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }
    my $id = $self->id;
    $item->{id} = $id;
    (my $status, $item) = $self->validate_item($item);
    if (is_error($status)) {
        return $self->render(status => $status, json => $item);
    }

    my $cs = $self->config_store;
    delete $item->{id};
    $cs->update($id, $item);
    return unless($self->commit($cs));
    $self->render(status => 200, json => { message => "Settings replaced"});
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

    return unless($self->commit($cs));
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

    my $parent = {
        placeholder => $self->standardPlaceholder
    };
    for my $field ($form->fields) {
        next if $field->inactive;
        my $name = $field->name;
        $meta{$name} = $self->field_meta($field, $parent);
        if ($name eq 'id') {
            $meta{$name}{default} = $self->id_field_default;
        }
    }

    return \%output;
}

=head2 standardPlaceholder

standardPlaceholder

=cut

sub standardPlaceholder {
    my ($self) = @_;
    my $values = $self->config_store->readDefaults;
    if ($values) {
        $values = $self->_cleanup_placeholder($self->cleanup_item($values));
    }

    return $values;
}

=head2 _cleanup_placeholder

_cleanup_placeholder

=cut

sub _cleanup_placeholder {
    my ($self, $placeholder) = @_;
    for my $key (keys %$placeholder) {
        my $val = $placeholder->{$key};
        if (!defined $val || (ref $val eq 'ARRAY' && @$val == 0)) {
            delete $placeholder->{$key};
        }
    }

    return $placeholder;
}

=head2 id_field_default

id_field_default

=cut

sub id_field_default { undef }

=head2 field_meta

Get a field's meta data

=cut

sub field_meta {
    my ($self, $field, $parent_meta, $no_array) = @_;
    my $type = $self->field_type($field, $no_array);
   my $meta = {
        type        => $type,
        required    => $self->field_is_required($field),
        placeholder => $self->field_placeholder($field, $parent_meta->{placeholder}),
        default     => $self->field_default($field, $parent_meta->{default}, $type),
    };
    my %extra = $self->field_extra_meta($field, $meta, $parent_meta);
    %$meta = (%$meta, %extra);

    if ($type ne 'array' && $type ne 'object') {
        if (defined (my $allowed = $self->field_allowed($field))) {
            $meta->{allowed} = $allowed;
            $meta->{allow_custom} = $self->field_allow_custom($field);
        } elsif (defined (my $allowed_lookup = $self->field_allowed_lookup($field))) {
            $meta->{allowed_lookup} = $allowed_lookup;
            $meta->{allow_custom} = $self->field_allow_custom($field);
        }

    }

    return $meta;
}

sub field_allow_custom {
    my ($self, $field) = @_;
    return $field->get_tag("allow_custom") ? $self->json_true : $self->json_false;
}

=head2 field_extra_meta

Get the extra meta data for a field

=cut

sub field_extra_meta {
    my ($self, $field, $meta, $parent_meta) = @_;
    my %extra;
    my $type = $meta->{type};
    if ($type eq 'array') {
        $extra{item} = $self->field_meta_array_items($field, undef, 1);
    } elsif ($type eq 'object') {
        $extra{properties} = $self->field_meta_object_properties($field, $meta);
    } else {
        if ($field->isa("HTML::FormHandler::Field::Text")) {
            $self->field_text_meta($field, \%extra);
        }

        if ($field->isa("HTML::FormHandler::Field::Integer") || $field->isa("HTML::FormHandler::Field::IntRange")) {
            $self->field_integer_meta($field, \%extra);
        }
    }
    if ($field->has_required_when) {
        my $required_when = $self->field_required_when($field, $meta, $parent_meta);
        if (defined $required_when) {
            $extra{required_when} = $required_when;
        }
    }

    return %extra;
}

=head2 field_required_when

field_required_when

=cut

sub field_required_when {
    my ($self, $field, $meta, $parent_meta) = @_;
    my $required_when = $field->required_when;
    if (any { ref $_ } values %$required_when) {
        return undef;
    }
    return $required_when;
}

=head2 field_meta_object_properties

Get the properties of a field

=cut

sub field_meta_object_properties {
    my ($self, $field, $meta) = @_;
    my %p;
    for my $f ($field->fields) {
        next if $field->inactive;
        $p{$f->name} = $self->field_meta($f, $meta);
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
    my $parent = {
        placeholder => $self->_cleanup_placeholder($inheritedValues)
    };
    for my $field ($form->fields) {
        next if $field->inactive;
        my $name = $field->name;
        next if $self->isResourceFieldSkippable($field);
        $meta{$name} = $self->field_meta($field, $parent);
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
    my $id = $self->id;
    my $values = $self->config_store->readInherited($id, 'id');
    if ($values) {
        $values->{id} = $id;
        $values = $self->cleanup_item($values);
    }

    return $values;
}

=head2 field_default

Get the default value of a field

=cut

sub field_default {
    my ($self, $field, $inheritedValues, $type) = @_;
    if ($type eq 'array') {
        return [];
    }
    my $default = $field->get_default_value;
    return $default // (ref($inheritedValues) eq 'HASH' ? $inheritedValues->{$field->name} : $inheritedValues);
}

=head2 default_values

Get the default values from the config section

=cut

sub default_values {
    my ($self) = @_;
    my $cs = $self->config_store;
    my $default_section = $cs->default_section;
    return $default_section ? $self->cleanup_item($cs->read($default_section, 'id')) : undef;
}

=head2 field_placeholder

Get the placeholder for the field

=cut

sub field_placeholder {
    my ($self, $field, $defaults) = @_;
    my $name = $field->name;
    my $value;
    if ($defaults) {
        $value = $defaults->{$name};
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
    my ($self, $field, $defaults) = @_;
    if ($field->isa('HTML::FormHandler::Field::Repeatable')) {
        $field->init_state;
        my $element = $field->clone_element($field->name . "_temp");
        if ($element->isa('HTML::FormHandler::Field::Select') ) {
            $element->_load_options();
        }

        return $self->field_meta($element, $defaults);
    }

    return $self->field_meta($field, $defaults, 1);
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
        } elsif ($field->isa('HTML::FormHandler::Field::Repeatable')) {
            $field->init_state;
            my $element = $field->clone_element($field->name . "_temp");
            if ($element->isa('HTML::FormHandler::Field::Select') ) {
                $element->_load_options();
                $allowed = $element->options;
            }
        } elsif ($field->isa('pfappserver::Form::Field::Toggle')) {
            my $check = $field->checkbox_value;
            my $uncheck = $field->unchecked_value;
            $allowed = [
                { label => $check, value => $check },
                { label => $uncheck, value => $uncheck },
            ];
        }
    }

    if ($allowed) {
        $allowed = $self->map_options($field, $allowed);
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
    my $allowed_lookup  = $field->get_tag("allowed_lookup") || undef;
    if ($allowed_lookup) {
        return $allowed_lookup;
    }

    if ($field->isa("pfappserver::Form::Field::FingerbankSelect") || $field->isa("pfappserver::Form::Field::FingerbankField")) {
        my $fingerbank_model = $field->fingerbank_model;
        my $name = $fingerbank_model->_parseClassName;
        my $path = $FB_MODEL_2_PATH{$name};
        return {
            search_path => "/api/v1/fingerbank/all/$path/search",
            field_name  => $fingerbank_model->value_field,
            value_name  => 'id',
        };
    }

    return undef;
}

=head2 map_options

map_options

=cut

sub map_options {
    my ($self, $field, $options) = @_;
    return [ map { $self->map_option($field, $_) } @$options ];
}

=head2 map_option

map_option

=cut

sub map_option {
    my ($self, $field, $option) = @_;
    my %hash = %$option;

    if (exists $hash{label}) {
        $hash{text} = (delete $hash{label} // '') . "";
        if ($field->can('localize_labels') && $field->localize_labels) {
            $hash{text} = $field->_localize($hash{text});
        }
    }

    if (exists $hash{options}) {
       $hash{options} = $self->map_options($field, $hash{options});
       delete $hash{value};
    } elsif (exists $hash{value} && defined $hash{value} && $hash{value} eq '' && $field->required) {
        return;
    }

    return \%hash;
}

=head2 bulk_update

bulk_update

=cut

sub bulk_update {
    my ($self) = @_;
    my ($error, $data) = $self->get_json;
    if (defined $error) {
        return $self->render_error( 400, "Bad Request : $error" );
    }

    my $items = $data->{items} // [];
    return $self->bulk_action($items, "bulk_update_callback");
}

=head2 bulk_update_callback

bulk_update_callback

=cut

sub bulk_update_callback {
    my ($self, $cs, $id, $item, $results) = @_;
    my $old_item = $self->item($id);
    my $new_item = {%$old_item, %$item};
    $new_item->{id} = $id;
    my ($status, $new_data) = $self->validate_item($new_item);
    if (is_error($status)) {
        %$results = (%$results, %$new_data);
        return $status;
    }

    delete $new_data->{id};
    if ($cs->update($id, $new_data)) {
        return 200;
    }

    $results->{message} = "unable to update";
    return 422;
}

=head2 bulk_delete

bulk_delete

=cut

sub bulk_delete {
    my ($self) = @_;
    my ($error, $data) = $self->get_json;
    if (defined $error) {
        return $self->render_error( 400, "Bad Request : $error" );
    }

    my $items = $data->{items} // [];
    $items = [map { { id => $_ }  } @$items];
    return $self->bulk_action($items, "bulk_delete_callback");
}

=head2 bulk_delete_callback

bulk_delete_callback

=cut

sub bulk_delete_callback {
    my ($self, $cs, $id, $item, $results) = @_;
    if ($cs->remove($id)) {
        return 200;
    }

    $results->{message} = "unable to delete";
    return 422;
}

sub bulk_action {
    my ($self, $items, $action) = @_;
    my $cs = $self->config_store;
    my @results;
    my $i = 0;
    my $success = 0;
    for my $item (@$items) {
        my $id = delete $item->{id};
        my %results = (
            index  => $i,
            id     => $id,
            status => 200,
        );

        push @results, \%results;

        if (!defined $id) {
            $results{status} = 422;
            $results{message} = "no id given";
            next;
        }

        if (!$cs->hasId($id)) {
            $results{status} = 422;
            $results{message} = "'$id' is not found";
            next;
        }

        my $status = $self->$action($cs, $id, $item, \%results);
        if (is_success($status)) {
            $success++;
        }

        $results{status} = $status;
    } continue {
        $i++;
    }

    if ($success) {
        $cs->commit();
    }

    return $self->render(status => 200, json => { items => \@results });
}

=head2 form_parameters

The form parameters should be overridded

=cut

sub form_parameters {
    []
}

sub checkup {
    my ($self) = @_;
    $self->render(json => { items => [pf::pfcmd::checkup::sanity_check()] });
}

=head2 fix_permissions

fix_permissions

=cut

sub fix_permissions {
    my ($self) = @_;
    my $result = pf::util::fix_files_permissions();
    chomp($result);
    return $self->render(json => { message => $result });
}

sub bulk_import {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my $items = $data->{items} // [];
    my $count = @$items;
    if ($count == 0) {
        return $self->render(json => { items => [] });
    }
    my $cs = $self->config_store;

    my $stopOnError = $data->{stopOnFirstError};
    my @results;
    $#results = $count - 1;
    my $i;
    my $changed = 0;
    for ($i=0;$i<$count;$i++) {
        my $result = $self->import_item($data, $items->[$i], $cs);
        $results[$i] = $result;
        $status = $result->{status} // 200;
        if ($stopOnError && $status == 422) {
            $i++;
            last;
        }

        $changed |= 1;
    }

    for (;$i<$count;$i++) {
        my $item = $items->[$i];
        my $result = { item => $item, status => 424, message => "Skipped" };
        $results[$i] =  $result;
        my $error = $self->import_item_check_for_errors($data, $item);
        if ($error) {
            %$result = (%$result, %$error);
        }
    }
    if ($changed) {
        $cs->commit;
    }

    return $self->render(json => { items => \@results });
}

sub import_item {
    my ($self, $request, $item, $cs) = @_;
    my $id = $item->{id};
    if (!defined $id) {
        return { field => 'id', message => 'Field id missing', status => 422 };
    }
    my $old_item = $self->item_from_store($item->{id});
    my $error = $self->import_item_check_for_errors($request, $item, $old_item);
    if ($error) {
        return { %$error,  item => $item,  status => 422, };
    }
    
    if ($old_item) {
        if ($request->{ignoreUpdateIfExists}) {
            return { item => $item, status => 409, message => "Skip already exists", isNew => $self->json_false} ;
        }

    } else {
        if ($request->{ignoreInsertIfNotExists}) {
            return { item => $item, status => 404, message => "Skip does not exists", isNew => $self->json_true} ;
        }
    }

    delete $item->{id};
    if ($old_item) {
        $cs->update($id, $item);
    } else {
        $cs->create($id, $item);
    }

    $item->{id} = $id;
    return { item => $item, status => 200, isNew => ( defined $old_item ? $self->json_false : $self->json_true ) };
}

sub import_item_check_for_errors {
    my ($self, $request, $item, $old_item) = @_;
    my $new_item = {%{$old_item // {}}, %$item};
    my ($status, $new_data) = $self->validate_item($new_item);
    if (is_error($status)) {
        return $new_data;
    }

    return;
}

sub parse_condition {
    my ($self) = @_;
    my ($error, $item) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }

    my $condition = $item->{condition};
    if (!defined $condition) {
        return $self->render_error(422, "No condition found");
    }

    if (ref $condition) {
        return $self->render_error(422, "Condition must be a string");
    }

    my ($ast, $err) = parse_condition_string($condition);
    if ($err) {
        return $self->render_error(422, "Cannot parse condition", [$err]);
    }

    $self->render(json => { item => {condition_string => $condition, condition => ast_to_object($ast) } });
}

sub flatten_condition {
    my ($self) = @_;
    my ($error, $item) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }

    my $condition = $item->{condition};
    if (!defined $condition) {
        return $self->render_error(422, "No condition found");
    }

    if (!ref $condition) {
        return $self->render_error(422, "Condition must be a object");
    }

    my $string = pf::condition_parser::object_to_str($condition);

    $self->render(json => { item => {condition_string => $string, condition => $condition } });
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
