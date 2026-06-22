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
use pf::log;
use pf::file_paths qw($kafka_ssl_dir);
use pf::cluster;
use pf::api::unifiedapiclient;
use pf::dal::pki_certs;
use pf::dal::pki_cas;
use File::Path qw(make_path);
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::UnifiedApi::OpenAPI::Generator::Config;
use pf::UnifiedApi::Controller::Config;
use pfappserver::Form::Config::Kafka;
use pf::ConfigStore::Kafka;
use pf::UnifiedApi::OpenAPI::Generator::Config;

# The conventional pfpki profile name used to issue Kafka broker certificates
use constant KAFKA_PKI_PROFILE_NAME => 'kafka-mtls';
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
        # The peer CA may have changed on save: rebuild the truststore on disk
        # and distribute the ssl artifacts to the rest of the cluster. Re-push
        # the whole ssl dir as well so a save converges any member that is
        # missing the artifacts (e.g. it was down when the cert was generated).
        eval { $self->_sync_peer_truststore() };
        if ($@) {
            get_logger->error("Unable to refresh the Kafka truststore: $@");
        }
        eval { $self->_sync_ssl_dir() };
        if ($@) {
            get_logger->error("Unable to distribute the Kafka ssl artifacts: $@");
        }
        $self->render(status => 200, json => {});
    }
}

sub save_in_config_store {
    my ($self, $data) = @_;
    my $cs = $self->config_store;
    $self->_preserve_managed_ssl($cs, $data);
    my $items = flatten_item($data);
    my $ini = $cs->cachedConfig();
    $ini->Delete();
    for my $item (@$items) {
         $cs->update_or_create($item->{section}, $item->{params} // {});
    }

    return $self->commit($cs);
}

=head2 _preserve_managed_ssl

The keystore/truststore passwords and the auto-managed pfpki profile id are
generated server-side (kafka-init / generate_cert) and are intentionally absent
from the admin form, so a submitted payload carries them empty. Since the save
rewrites kafka.conf from scratch, carry the existing values forward whenever the
incoming payload does not provide one, otherwise they would be wiped.

=cut

sub _preserve_managed_ssl {
    my ($self, $cs, $data) = @_;
    return unless ref($data->{ssl}) eq 'HASH';
    my $existing = $cs->read('ssl') || {};
    for my $key (qw(keystore_password truststore_password profile_id)) {
        my $val = $data->{ssl}{$key};
        next if defined $val && $val ne '';
        $data->{ssl}{$key} = $existing->{$key}
            if defined $existing->{$key} && $existing->{$key} ne '';
    }
    return;
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
    ssl => undef,
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

        push @host_configs, { config => \@host_config, host => $id };
    }

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

=head2 generate_cert

Generate (or renew) the Kafka broker certificate using a pfpki CA.

Ensures a dedicated pfpki profile exists for the selected CA, signs a broker
certificate against it, then writes the keystore (PKCS12) and the PEM artifacts
to C<$kafka_ssl_dir>. In a cluster the artifacts are distributed to every node.

=cut

sub generate_cert {
    my ($self) = @_;
    my ($error, $data) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }
    $data //= {};

    my $cs  = $self->config_store;
    my $ssl = $cs->read('ssl') || {};

    # Posted values take precedence over the saved [ssl] config
    my $ca_id        = $data->{ca_id}        // $ssl->{ca_id};
    my $cn           = $data->{cn}           // $ssl->{cn};
    my $dns_names    = $data->{dns_names}    // $ssl->{dns_names}    // '';
    my $ip_addresses = $data->{ip_addresses} // $ssl->{ip_addresses} // '';
    my $keystore_password = $ssl->{keystore_password};

    unless (defined $ca_id && $ca_id ne '') {
        return $self->render_error(422, "A pfpki Certificate Authority (ca_id) must be selected");
    }
    unless (defined $cn && $cn ne '') {
        return $self->render_error(422, "A Common Name (cn) is required");
    }
    unless (defined $keystore_password && $keystore_password ne '') {
        return $self->render_error(422, "The keystore password is not initialized (run kafka-init)");
    }

    # In a cluster, the single shared certificate must carry every broker's
    # advertised address in its SANs so it validates on all nodes.
    if ($cluster_enabled) {
        ($dns_names, $ip_addresses) = $self->_expand_cluster_sans($dns_names, $ip_addresses);
    }

    my $client = pf::api::unifiedapiclient->default_client;

    my ($profile_id, $profile_name) = eval { $self->_ensure_kafka_profile($client, $ca_id) };
    if ($@ || !$profile_id) {
        return $self->render_error(500, "Unable to find or create the Kafka PKI profile: " . ($@ || 'unknown error'));
    }

    my $cert_resp = eval {
        $client->call("POST", "/api/v1/pki/certs", {
            cn           => $cn,
            profile_id   => "$profile_id",   # pfpki expects profile_id as a JSON string (,string tag)
            dns_names    => $dns_names,
            ip_addresses => $ip_addresses,
        });
    };
    if ($@ || !$cert_resp) {
        return $self->render_error(500, "Certificate generation failed: " . ($@ || 'unknown error'));
    }

    my $item   = (ref($cert_resp->{items}) eq 'ARRAY') ? $cert_resp->{items}[0] : undef;
    my $serial = $cert_resp->{serial} // ($item ? $item->{serial_number} : undef);

    my ($key_pem, $cert_pem) = $self->_read_cert_material($cn, $serial);
    my $ca_pem = $self->_read_ca_cert($ca_id);
    unless ($key_pem && $cert_pem && $ca_pem) {
        return $self->render_error(500, "Unable to read the generated certificate material from the database");
    }

    # Persist the (possibly newly created) profile id and the resolved SANs
    $self->_persist_ssl($cs, {
        ca_id        => $ca_id,
        profile_id   => $profile_id,
        cn           => $cn,
        dns_names    => $dns_names,
        ip_addresses => $ip_addresses,
    });

    my @files = eval { $self->_write_keystore($key_pem, $cert_pem, $ca_pem, $keystore_password) };
    if ($@) {
        return $self->render_error(500, "Unable to write the keystore files: $@");
    }

    # (Re)build the peer truststore so a freshly generated keystore and the
    # truststore are always in sync on disk, then distribute to the cluster.
    eval { push @files, $self->_write_truststore($ssl->{peer_ca}, $ssl->{truststore_password}) };
    if ($@) {
        get_logger->error("Unable to build the Kafka truststore: $@");
    }
    $self->_sync_ssl_dir();

    return $self->render(status => 200, json => {
        serial      => $serial,
        profile_id  => $profile_id,
        valid_until => ($item ? $item->{valid_until} : undef),
        files       => \@files,
    });
}

=head2 _ensure_kafka_profile

Find the dedicated Kafka pfpki profile for the given CA, creating it if needed.
Returns C<($profile_id, $profile_name)>.

=cut

sub _ensure_kafka_profile {
    my ($self, $client, $ca_id) = @_;

    my $search = $client->call("POST", "/api/v1/pki/profiles/search", {
        query => {
            op     => 'and',
            values => [
                { field => 'ca_id', op => 'equals', value => $ca_id },
                { field => 'name',  op => 'equals', value => KAFKA_PKI_PROFILE_NAME },
            ],
        },
        limit => 1,
    });
    if ($search && ref($search->{items}) eq 'ARRAY' && @{$search->{items}}) {
        my $p = $search->{items}[0];
        return ($p->{ID} // $p->{id}, $p->{name} // $p->{Name});
    }

    # extended_key_usage "1|2" => serverAuth + clientAuth (the broker is both a
    # TLS server to the peer and a TLS client to it during the mutual handshake)
    # pfpki decodes these numeric fields from JSON strings (the ,string struct
    # tags in pfpki/models), matching how the webadmin posts form values, so
    # send them quoted -- an unquoted number fails to unmarshal.
    my $created = $client->call("POST", "/api/v1/pki/profiles", {
        name               => KAFKA_PKI_PROFILE_NAME,
        ca_id              => "$ca_id",
        validity           => "825",
        key_type           => "1",
        key_size           => "2048",
        digest             => "4",
        key_usage          => "1|4",
        extended_key_usage => "1|2",
    });
    my $p = (ref($created->{items}) eq 'ARRAY') ? $created->{items}[0] : $created;
    return ($p->{ID} // $p->{id}, $p->{name} // $p->{Name});
}

=head2 _read_cert_material

Read the private key and certificate PEM for the issued certificate from the
pki_certs table (the create API intentionally omits the private key).

=cut

sub _read_cert_material {
    my ($self, $cn, $serial) = @_;
    # Prefer an exact match on the serial returned by the create call; fall back
    # to the most recently issued certificate for this CN (the one we just made).
    for my $where ( ($serial ? ({ cn => $cn, serial_number => $serial }) : ()), { cn => $cn } ) {
        my ($status, $iter) = pf::dal::pki_certs->search(
            -where    => $where,
            -order_by => { -desc => 'id' },
            -limit    => 1,
            -with_class => undef,
        );
        next unless is_success($status);
        my $row = $iter->next or next;
        return ($row->{key}, $row->{cert});
    }
    return;
}

=head2 _read_ca_cert

Read the CA certificate PEM for the given CA id from the pki_cas table.

=cut

sub _read_ca_cert {
    my ($self, $ca_id) = @_;
    my ($status, $iter) = pf::dal::pki_cas->search(
        -where    => { id => $ca_id },
        -limit    => 1,
        -with_class => undef,
    );
    return unless is_success($status);
    my $row = $iter->next;
    return unless $row;
    return $row->{cert};
}

=head2 _persist_ssl

Persist the given key/value pairs into the [ssl] section and commit.

=cut

sub _persist_ssl {
    my ($self, $cs, $params) = @_;
    my $ssl = $cs->read('ssl') || {};
    $cs->update_or_create('ssl', { %$ssl, %$params });
    $self->commit($cs);
}

=head2 _ssl_dir

Ensure the kafka ssl directory exists and return its path.

=cut

sub _ssl_dir {
    my ($self) = @_;
    make_path($kafka_ssl_dir) unless -d $kafka_ssl_dir;
    return $kafka_ssl_dir;
}

=head2 _write_file

Write content to a file under the ssl dir with the given mode, owned by pf.

=cut

sub _write_file {
    my ($self, $name, $content, $mode) = @_;
    my $path = $self->_ssl_dir . "/$name";
    open(my $fh, '>', $path) or die "cannot write $path: $!\n";
    print {$fh} $content;
    close($fh);
    chmod($mode, $path);
    if ($ENV{PF_UID} && $ENV{PF_GID}) {
        chown($ENV{PF_UID}, $ENV{PF_GID}, $path);
    }
    return $path;
}

=head2 _write_keystore

Write key.pem, cert.pem, ca.pem and build the PKCS12 keystore (key + cert + CA
chain). Returns the list of file paths written.

=cut

sub _write_keystore {
    my ($self, $key_pem, $cert_pem, $ca_pem, $password) = @_;
    my $key_path  = $self->_write_file('key.pem',  $key_pem,  0600);
    my $cert_path = $self->_write_file('cert.pem', $cert_pem, 0644);
    my $ca_path   = $self->_write_file('ca.pem',   $ca_pem,   0644);
    my $ks_path   = $self->_ssl_dir . "/keystore.p12";

    local $ENV{PF_KAFKA_KS_PASS} = $password;
    my @cmd = (
        'openssl', 'pkcs12', '-export',
        '-inkey',    $key_path,
        '-in',       $cert_path,
        '-certfile', $ca_path,
        '-name',     'kafka',
        '-out',      $ks_path,
        '-passout',  'env:PF_KAFKA_KS_PASS',
    );
    system(@cmd) == 0 or die "openssl keystore generation failed (exit " . ($? >> 8) . ")\n";
    # The keystore is distributed to the other cluster members by the pf-owned
    # config-sync process, which must be able to read it; the private key inside
    # is protected by the keystore password, so a readable mode is safe here.
    chmod(0644, $ks_path);
    if ($ENV{PF_UID} && $ENV{PF_GID}) {
        chown($ENV{PF_UID}, $ENV{PF_GID}, $ks_path);
    }
    return ($key_path, $cert_path, $ca_path, $ks_path);
}

=head2 _write_truststore

Write the peer CA PEM and build a PKCS12 truststore from it. Returns the list of
file paths written (empty if no peer CA is configured).

=cut

sub _write_truststore {
    my ($self, $peer_ca, $password) = @_;
    return () unless defined $peer_ca && $peer_ca =~ /\S/;
    return () unless defined $password && $password ne '';

    my $peer_path = $self->_write_file('peer-ca.pem', $peer_ca, 0644);
    my $ts_path   = $self->_ssl_dir . "/truststore.p12";

    local $ENV{PF_KAFKA_TS_PASS} = $password;
    my @cmd = (
        'openssl', 'pkcs12', '-export', '-nokeys',
        '-in',      $peer_path,
        '-name',    'kafka-peer-ca',
        '-out',     $ts_path,
        '-passout', 'env:PF_KAFKA_TS_PASS',
    );
    system(@cmd) == 0 or die "openssl truststore generation failed (exit " . ($? >> 8) . ")\n";
    # Readable for the same cluster-sync reason as the keystore (password-protected).
    chmod(0644, $ts_path);
    if ($ENV{PF_UID} && $ENV{PF_GID}) {
        chown($ENV{PF_UID}, $ENV{PF_GID}, $ts_path);
    }
    return ($peer_path, $ts_path);
}

=head2 _sync_peer_truststore

Rebuild the peer truststore from the saved config and distribute it. Used after
a config save so a changed peer CA is reflected on disk.

=cut

sub _sync_peer_truststore {
    my ($self) = @_;
    my $ssl = $self->config_store->read('ssl') || {};
    my @files = $self->_write_truststore($ssl->{peer_ca}, $ssl->{truststore_password});
    $self->_sync_ssl_dir() if @files;
    return;
}

=head2 _expand_cluster_sans

Merge the configured SANs with every cluster member's management IP so the
shared certificate validates on all brokers. Returns C<($dns_names, $ips)>.

=cut

sub _expand_cluster_sans {
    my ($self, $dns_names, $ip_addresses) = @_;
    my %ips = map { $_ => 1 } grep { /\S/ } split(/\s*,\s*/, $ip_addresses // '');
    for my $server (pf::cluster::enabled_servers()) {
        $ips{$server->{management_ip}} = 1 if $server->{management_ip};
    }
    return ($dns_names, join(",", sort keys %ips));
}

=head2 _sync_ssl_dir

Distribute the kafka ssl artifacts to the other cluster members using the same
file sync as C<@FILES_TO_SYNC>: each member pulls the files from this (origin)
server. The broker loads the password-protected keystore/truststore; the public
PEMs and the client key.pem are distributed so the pfkafka client tool can do
mTLS on every member (it loads cert.pem + key.pem from disk). key.pem lands 0664
on the receivers (the cluster file sync forces that mode); this is no extra
exposure since the same private key already travels inside the synced keystore.p12,
whose password lives in the (0664) kafka.conf.

=cut

sub _sync_ssl_dir {
    my ($self) = @_;
    return unless $cluster_enabled;
    my @files = grep { -f $_ }
        map { "$kafka_ssl_dir/$_" }
        qw(ca.pem cert.pem key.pem peer-ca.pem keystore.p12 truststore.p12);
    return unless @files;
    my $failed = eval { pf::cluster::sync_files(\@files) };
    if ($@) {
        get_logger->error("Unable to distribute the Kafka ssl files to the cluster: $@");
    }
    elsif ($failed && @$failed) {
        # sync_files does not die on per-member failures, it returns the list of
        # members it could not reach/write -- surface it so a failed distribution
        # is visible on the issuing node instead of only on the receivers.
        get_logger->error("Unable to distribute the Kafka ssl files to cluster member(s): " . join(", ", @$failed));
    }
    return;
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
