package pf::UnifiedApi::Controller::Config::Kafka;

=head1 NAME

pf::UnifiedApi::Controller::Config::Kafka -

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Kafka

=cut

use strict;
use warnings;
use pf::error qw(is_error is_success);
use pf::util qw(listify);
use pf::constants qw($TRUE);
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::UnifiedApi::OpenAPI::Generator::Config;
use pf::UnifiedApi::Controller::Config;
use pfappserver::Form::Config::Kafka;
use pf::ConfigStore::Kafka;
use pf::UnifiedApi::OpenAPI::Generator::Config;
has 'config_store_class' => 'pf::ConfigStore::Kafka';
has 'form_class' => 'pfappserver::Form::Config::Kafka';
has 'openapi_generator_class' => 'pf::UnifiedApi::OpenAPI::Generator::Config';

sub get {
    my ($self) = @_;
    my $item = $self->item;
    return $self->render(json => {item => $item}, status => 200);
}

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
    my $placeholder = $self->standardPlaceholder;
    my $parent = {
        placeholder => $placeholder
    };
    for my $field ($form->fields) {
        next if $field->inactive;
        my $name = $field->name;
        $meta{$name} = $self->field_meta($field, $parent);
        if ($name eq 'id') {
            $meta{$name}{default} = $self->id_field_default;
        }
    }

    $self->cleanup_options(\%output, $placeholder);
    return \%output;
}

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

    if ($type eq 'file') {
        $meta->{accept} = {
            type => 'String',
            default => '*/*'
        };
    }

    $meta->{implied} = $self->field_implied($field);
    return $meta;
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

sub standardPlaceholder {
    my ($self) = @_;
    $self->config_store->readDefaults;
}

=head2 field_placeholder

Get the placeholder for the field

=cut

sub field_placeholder {
    my ($self, $field, $defaults) = @_;
    my $name = $field->name;
    my $value;
    if ($field->type_attr eq 'password') {
        return '**************';
    }

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

sub field_implied {
    my ($self, $field) = @_;
    my $v = $field->get_tag("implied");
    $v = undef if $v eq '';
    return $v;
}

sub field_allow_custom {
    my ($self, $field) = @_;
    return $field->get_tag("allow_custom") ? $self->json_true : $self->json_false;
}

=head2 map_options

map_options

=cut

sub map_options {
    my ($self, $field, $options) = @_;
    return [ map { $self->map_option($field, $_) } @$options ];
}

sub cleanup_options {}

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

sub update {
    my ($self) = @_;
    my ($error, $data) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }
    my ($status, $new_data, $form) = $self->validate_item($data);
    if (is_error($status)) {
        return $self->render(status => $status, json => $new_data);
    }

    if ($self->save_in_config_store($new_data)) {
        $self->render(status => 200, json => {});
    }
}

sub save_in_config_store {
    my ($self, $data) = @_;
    my $items = flatten_item($data);
    my $cs = $self->config_store;
    my $ini = $cs->cachedConfig();
    $ini->Delete();
    for my $item (@$items) {
         $cs->update_or_create($item->{section}, $item->{params} // {});
    }

    return $self->commit($cs);
}

sub commit {
    my ($self, $cs) = @_;
    my ($res, $msg) = $cs->commit();

    if($ENV{PF_UID} && $ENV{PF_GID}) {
        chown($ENV{PF_UID}, $ENV{PF_GID}, $cs->configFile);
    }

    unless($res) {
        $self->render_error(500, $msg);
        return undef;
    }
    return $TRUE;
}

sub validate_item {
    my ($self, $item) = @_;
    $item = $self->cleanupItemForValidate($item);
    my ($status, $form) = $self->form($item);
    if (is_error($status)) {
        return $status, { message => $form }, undef;
    }

    $form->process($self->form_process_parameters_for_validation($item));
    if (!$form->has_errors) {
        return 200, $form->value, $form;
    }

    return 422, { message => "Unable to validate", errors => $self->format_form_errors($form) }, undef;
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


sub form_process_parameters_for_validation {
    my ($self, $item) = @_;
    return (posted => 1, params => $item);
}

sub cleanupItemForValidate {
    my ($self, $item) = @_;
    return $item;
}

sub form {
    my ($self, $item, @args) = @_;
    my $form = $self->form_class->new(@args, user_roles => $self->stash->{'admin_roles'});
    return 200, $form;
}

sub config_store {
    my ($self) = @_;
    $self->config_store_class->new;
}

our %fields = (
    iptables => undef,
    admin => undef,
);

sub item {
    my ($self) = @_;
    my $cs = $self->config_store;
    my @auth;
    my @cluster;
    my @host_configs;
    my %item = (
        auths => \@auth,
        cluster => \@cluster,
        host_configs => \@host_configs,
    );

    for my $id ($cs->_Sections()) {
        if (exists $fields{$id}) {
            my $d = $cs->read($id);
            if ($id eq 'iptables') {
                for my $f (qw(clients cluster_ips)) {
                    $d->{$f} = [split /\s*,\s*/, $d->{$f}];
                }
            }
            $item{$id} = $d;
            next;
        }

        if ($id =~ /^auth (.*)$/) {
            my $user = $1;
            my $d = $cs->read($id);
            $d->{user} = $user;
            push @auth, $d;
            next;
        }

        if ($id eq 'cluster') {
            my $d = $cs->read($id);
            while (my ($k,$v) = each %$d) {
                push @cluster, { name => $k, value => $v};
            }
            next;
        }

        my @host_config;
        my $d = $cs->read($id);
        while (my ($k,$v) = each %$d) {
            push @host_config, { name => $k, value => $v};
        }

        @host_configs = { config => \@host_config, host => $id };
    }

    @host_configs = sort { $a->{host} <=> $b->{host} } @host_configs;
    return \%item;
}

sub flatten_name_val {
    my ($config) = @_;
    my %params;
    for my $e (@$config) {
        $params{$e->{name}} = $e->{value};
    }
    return \%params;
}

sub flatten_host_config {
    my ($config) = @_;
    return { section => $config->{host}, params => flatten_name_val($config->{config}) };
}

sub flatten_auth {
    my ($config) = @_;
    return { section => "auth $config->{user}", params => {pass => $config->{pass}} };
}

sub flatten_iptables {
    my ($config) = @_;
    my %params;
    while ( my ($k, $v) = each %$config ) {
       $params{$k} = join(",", @{listify($v)});
    }

    return { section => "iptables", params => \%params };
}

sub flatten_item {
    my ($data) = @_;
    my @flatten_items;
    while (my ($k, $value) = each %$data) {
        if ($k eq 'host_configs') {
            for my $e (@$value) {
                push @flatten_items, flatten_host_config($e);
            }
            next;
        }
        if ($k eq 'cluster') {
            push @flatten_items, { section => $k, params => flatten_name_val($value)};
            next;
        }

        if ($k eq 'auths') {
            foreach my $element ( @$value ) {
                push @flatten_items, flatten_auth($element);
            }
            next;
        }

        if ($k eq 'iptables') {
            push @flatten_items, flatten_iptables($value);
            next;
        }

        push @flatten_items, {section => $k, params => $value};
    }

    return \@flatten_items;
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
