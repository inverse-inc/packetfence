package pf::UnifiedApi::Controller::Config::Domains;

=head1 NAME

pf::UnifiedApi::Controller::Config::Domains -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Domains

=cut

use strict;
use warnings;

use Mojo::Base qw(pf::UnifiedApi::Controller::Config);

has 'config_store_class' => 'pf::ConfigStore::Domain';
has 'form_class' => 'pfappserver::Form::Config::Domain';
has 'primary_key' => 'domain_id';

use pf::ConfigStore::Domain;
use pfappserver::Form::Config::Domain;
use pf::domain;
use pf::factory::connector;
use pf::error qw(is_error);
use pf::pfqueue::producer::redis;
use pf::util;
use pf::constants qw($TRUE $FALSE);
use Sys::Hostname;
use Socket;
use Digest::MD4 qw(md4_hex);
use Encode qw(encode);
use Net::DNS;
use JSON;
use pf::constants qw($TRUE $FALSE);
use pf::config::crypt;
use pf::config qw(%Config);
use pf::log;

use constant JOIN_REMOTE_PORT_OFFSET => 200;

# The ntlm-join-remote service listens on this address:port on the connector-remote
# side (see go/cmd/ntlm-join-remote and resource::pfconnector_static_connections).
# For connector-backed domains we reach it on demand through a dynreverse tunnel
# rather than a pre-provisioned static tunnel.
use constant JOIN_REMOTE_TARGET_HOST => '100.64.0.1';
use constant JOIN_REMOTE_TARGET_PORT => 23000;

# Connector-backed domains are namespaced under this stable, tenant-wide prefix
# instead of the (ephemeral, per-pod) hostname. A domain served through a
# connector isn't owned by any single PF host — it may even be served by several
# connectors at once (AD on one side, cache-only ntlm-auth-api on another) — so
# every pod/host must resolve the same section and config::Domain must surface it
# cluster-wide. Classic, host-local domains keep the hostname prefix.
use constant CONNECTOR_HOST_ID => 'connector';

my $host_id = hostname();

sub id {
    my ($self) = @_;
    my $primary_key = $self->primary_key;
    my $stash = $self->stash;
    return undef unless exists $stash->{$primary_key};
    my $bare = $stash->{$primary_key};
    # Resolve the stored section for this bare id. Connector-backed domains live
    # under the stable CONNECTOR_HOST_ID prefix; classic domains under this host's
    # hostname. Prefer an existing section; fall back to the host prefix for ids
    # that don't exist yet.
    my $cs = $self->config_store;
    for my $prefix (CONNECTOR_HOST_ID, $host_id) {
        my $candidate = "$prefix $bare";
        return $candidate if $cs->hasId($candidate);
    }
    return "$host_id $bare";
}

=head2 get

get a domain config, and strip host_id prefix.

=cut

sub get {
    my ($self) = @_;
    my $item = $self->item;
    if ($item) {
        $item->{id} =~ s/^\S+\s+//;
        $item = $self->cleanupItemForGet($item);
        return $self->render(json => { item => $item }, status => 200);
    }
    return $self->render_error(500, "Unknown error getting item");
}

sub item_shown {
    my ($self, $item) = @_;
    if ($item->{id} =~ s/^\S+\s+//) {
        return $TRUE;
    }
    return $FALSE;
}

sub handle_search {
    my ($self, $search_info) = @_;
    my ($status, $response) = $self->search_builder->search($search_info);
    if (is_error($status)) {
        return $self->render_error(
            $status,
            $response->{message},
            $response->{errors}
        );
    }

    unless ($search_info->{raw}) {
        $response->{items} = $self->cleanup_items($response->{items} // []);
    }

    foreach my $item (@{$response->{items}}) {
        $item->{id} =~ s/^\S+\s+//;
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

sub create {
    my ($self) = @_;
    my ($error, $item) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }

    my $id = $item->{id};
    if (!defined $id || length($id) == 0) {
        $self->render_error(422, "Unable to validate", [ { message => "id field is required", field => 'id' } ]);
        return 0;
    }

    my $use_connector = isenabled($item->{use_connector});
    # Connector-backed domains share the stable CONNECTOR_HOST_ID namespace; classic
    # domains are namespaced under this host. ntlm_auth_port is allocated per
    # namespace, so scan (below) and section id (further down) both key off it.
    my $host_prefix = $use_connector ? CONNECTOR_HOST_ID : $host_id;

    my $cs = $self->config_store;
    my $sections = $cs->readAllIds;
    my $max_port = 4999;
    for my $section (@$sections) {
        unless ($section =~ /^\Q$host_prefix\E /) {
            next;
        }
        my $ntlm_auth_port = $cs->cachedConfig->val($section, "ntlm_auth_port");
        if (defined($ntlm_auth_port)) {
            if (int($ntlm_auth_port) > $max_port) {
                $max_port = $ntlm_auth_port;
            }
        }
    }
    $max_port = $max_port + 1;

    # Validate against the raw, user-supplied id. The host_id prefix below is an
    # internal namespacing detail for the config-store section and must not count
    # against the id field's maxlength (would spuriously fail on long cloud hostnames).
    $item = $self->cleanupItemForCreate($item);
    (my $status, $item, my $form) = $self->validate_item($item);
    if (is_error($status)) {
        return $self->render(status => $status, json => $item);
    }

    $id = $host_prefix . " " . (delete $item->{id} // $id);
    if ($cs->hasId($id)) {
        return $self->render_error(409, "An attempt to add a duplicate entry was stopped. Entry already exists and should be modified instead of created");
    }

    my $bind_dn = $item->{bind_dn};
    my $bind_pass = pf::config::crypt::pf_decrypt($item->{bind_pass});
    my $computer_name = $item->{server_name};
    my $computer_password = $item->{machine_account_password};
    my $ad_fqdn = $item->{ad_fqdn};
    my $ad_server = $item->{ad_server};
    my $dns_name = $item->{dns_name};
    my $workgroup = $item->{workgroup};
    my $real_computer_name = $item->{server_name};
    my $ou = $item->{ou};
    my $additional_machine_accounts = $item->{additional_machine_accounts};
    my $force_ldap = isenabled($item->{force_ldap});
    my %ssl_options = (
        client_cert_file => $item->{client_cert_file},
        client_key_file => $item->{client_key_file},
        encryption => $item->{encryption},
        ca_file => $item->{ca_file},
        channel_binding => isenabled($item->{channel_binding}),
    );

    if ($computer_name eq "%h") {
        $real_computer_name = hostname();
        my @s = split(/\./, $real_computer_name);
        $real_computer_name = $s[0];
    }

    if (length($real_computer_name) > 19) {
        return $self->render_error(422, "Invalid machine account length, maximum 20 characters (including ending\$ sign)")
    }

    my $ad_server_host = "";
    my $ad_server_ip = "";

    my $dns_servers = $item->{dns_servers};
    if ($use_connector) {
        # Connector-backed domain: the cloud cannot reach the customer's on-prem
        # dns_servers directly, so querying them here would stall ~75s before
        # falling back. Resolve the AD server through the connector instead — a bare
        # IP is used as-is, a hostname goes through pfdns-connector (and is checked
        # against the connector networks).
        my $resolved_ip = pf::factory::connector->resolve($ad_server);
        if (defined($resolved_ip) && valid_ip($resolved_ip)) {
            $ad_server_host = $ad_fqdn;
            $ad_server_ip = $resolved_ip;
        }
        else {
            return $self->render_error(422, "Unable to resolve AD server '$ad_server' through the connector. Provide an IP within a connector's networks, or a name resolvable via pfdns-connector.\n");
        }
    }
    elsif (defined($dns_servers)) {
        my ($hostname, $ip, $error) = pf::util::dns_resolve($ad_fqdn, $dns_servers, $dns_name);
        if (defined($ip)) {
            $ad_server_host = $ad_fqdn;
            $ad_server_ip = $ip;
        }
        else {
            if (defined($ad_server) && valid_ip($ad_server)) {
                $ad_server_host = $ad_fqdn;
                $ad_server_ip = $ad_server;
            }
            else {
                return $self->render_error(422, "Unable to resolve AD FQDN: '$ad_fqdn' with given DNS server: '$dns_servers'\n");
            }
        }
    }
    else {
        $ad_server_host = $ad_fqdn;
        $ad_server_ip = $ad_server;
    }
    if (!valid_ip($ad_server_ip)) {
        return $self->render_error(422, "Unable to determine AD server's IP address.\n")
    }

    if (!is_nt_hash_pattern($computer_password)) {
        my $api_host = $Config{'services_host'}{'pfconnector_service_host'};
        my $api_port = $max_port + JOIN_REMOTE_PORT_OFFSET;

        # For connector-backed domains, reach ntlm-join-remote through an on-demand
        # dynreverse tunnel instead of a pre-provisioned static tunnel. This removes
        # the chicken-and-egg where the join needed a tunnel that only appeared after
        # the domain was committed and the connector reconnected.
        if ($use_connector) {
            my $err_msg;
            ($api_host, $api_port, $err_msg) = $self->connector_join_endpoint($ad_server_ip);
            if (defined($err_msg)) {
                return $self->render_error(422, $err_msg);
            }
        }

        my @real_computer_names = ($real_computer_name);
        if ($additional_machine_accounts + 0 > 0) {
            for my $i (0 .. $additional_machine_accounts - 1) {
                if (length("$real_computer_name-$i") > 19) {
                    return $self->render_error(422, "In order to create additional machine accounts, the base computer account is limited to maximum 16 characters. currently using '$real_computer_name', " + length($real_computer_name), " characters.")
                }
                push(@real_computer_names, "$real_computer_name-$i");
            }
        }
        for (my $i = 0; $i < @real_computer_names; $i++) {
            $real_computer_name = $real_computer_names[$i];

            my ($add_status, $add_result) = pf::domain::dispatch_add_computer($use_connector, $api_host, $api_port, " ", $real_computer_name, $computer_password, $ad_server_ip, $ad_server_host, $dns_name, $workgroup, $ou, $bind_dn, $bind_pass, $force_ldap, \%ssl_options);
            if ($add_status == $FALSE) {
                if ($add_result =~ /already exists(.+)use \-no\-add/) {
                    ($add_status, $add_result) = pf::domain::dispatch_add_computer($use_connector, $api_host, $api_port, "-delete", $real_computer_name, $computer_password, $ad_server_ip, $ad_server_host, $dns_name, $workgroup, $ou, $bind_dn, $bind_pass, $force_ldap, \%ssl_options);
                    if ($add_status == $FALSE) {
                        $self->render_error(422, "Unable to add machine account: removing existing machine account failed with following error: $add_result");
                        return 0;
                    }
                    ($add_status, $add_result) = pf::domain::dispatch_add_computer($use_connector, $api_host, $api_port, " ", $real_computer_name, $computer_password, $ad_server_ip, $ad_server_host, $dns_name, $workgroup, $ou, $bind_dn, $bind_pass, $force_ldap, \%ssl_options);
                    if ($add_status == $FALSE) {
                        $self->render_error(422, "Unable to add machine account: recreating machine account with following error: $add_result");
                        return 0;
                    }
                }
                else {
                    $self->render_error(422, "Unable to add machine account with following error: $add_result");
                    return 0;
                }
            }

        }
        my $encoded_password = encode("utf-16le", $computer_password);
        my $hash = md4_hex($encoded_password);
        $computer_password = $hash;
    }

    $item->{ntlm_auth_host} = 'containers-gateway.internal';
    $item->{ntlm_auth_port} = $max_port;
    $item->{password_is_nt_hash} = '1';
    $item->{machine_account_password} = $computer_password;
    $item->{server_name} = $computer_name;

    delete $item->{bind_dn};
    delete $item->{bind_pass};

    $cs->create($id, $item);
    return unless ($self->commit($cs));
    $self->post_create($id);
    # Bind the new domain's static tunnels on the connector now, so it's usable
    # without waiting for the connector to reconnect.
    $self->reprovision_connector_static($ad_server_ip) if $use_connector;
    my $additional_out = $self->additional_create_out($form, $item);

    $id =~ s/^\S+\s+//;
    $self->stash($self->primary_key => $id);
    $self->res->headers->location($self->make_location_url($id));
    $self->render(status => 201, json => $self->create_response($id, $additional_out));
}

sub update {
    my ($self) = @_;

    my ($error, $data) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }

    my $old_item = $self->item;

    my $new_item = $self->mergeUpdate($data, $self->item);

    # mergeUpdate sets the id to the host_id-namespaced value ($self->id); validate
    # against the raw id so the field's maxlength/pattern apply to the user-supplied
    # portion only (the prefix is an internal storage detail, not user input).
    $new_item->{id} =~ s/^\S+\s+//;

    my ($status, $new_data, $form) = $self->validate_item($new_item);
    if (is_error($status)) {
        return $self->render(status => $status, json => $new_data);
    }

    my $cs = $self->config_store;
    $self->cleanupItemForUpdate($old_item, $new_data, $data);

    my $bind_dn = $new_item->{bind_dn};
    my $bind_pass = $new_item->{bind_pass};
    my $computer_name = $old_item->{server_name};
    my $computer_password = $new_item->{machine_account_password};
    my $ad_fqdn = $new_item->{ad_fqdn};
    my $ad_server = $new_item->{ad_server};
    my $dns_name = $new_item->{dns_name};
    my $workgroup = $old_item->{workgroup};
    my $real_computer_name = $old_item->{server_name};
    my $ou = $new_item->{ou};
    my $additional_machine_accounts = $new_item->{additional_machine_accounts};
    my $force_ldap = isenabled($new_item->{force_ldap});
    my %ssl_options = (
        client_cert_file => $new_item->{client_cert_file},
        client_key_file => $new_item->{client_key_file},
        encryption => $new_item->{encryption},
        ca_file => $new_item->{ca_file},
        channel_binding => isenabled($new_item->{channel_binding}),
    );

    if ($computer_name eq "%h") {
        $real_computer_name = hostname();
        my @s = split(/\./, $real_computer_name);
        $real_computer_name = $s[0];
    }

    if (length($real_computer_name) > 19) {
        return $self->render_error(422, "Invalid machine account length, maximum 20 characters (including ending\$ sign)")
    }

    my $ad_server_host = "";
    my $ad_server_ip = "";

    my $use_connector = isenabled($new_item->{use_connector} // $old_item->{use_connector});
    my $dns_servers = $new_item->{dns_servers};
    if ($use_connector) {
        # Connector-backed domain: resolve the AD server through the connector
        # rather than the customer's on-prem dns_servers (unreachable from the
        # cloud, would stall ~75s). Bare IP used as-is; hostname via pfdns-connector.
        my $resolved_ip = pf::factory::connector->resolve($ad_server);
        if (defined($resolved_ip) && valid_ip($resolved_ip)) {
            $ad_server_host = $ad_fqdn;
            $ad_server_ip = $resolved_ip;
        }
        else {
            return $self->render_error(422, "Unable to resolve AD server '$ad_server' through the connector. Provide an IP within a connector's networks, or a name resolvable via pfdns-connector.\n");
        }
    }
    elsif (defined($dns_servers)) {
        my ($hostname, $ip, $error) = pf::util::dns_resolve($ad_fqdn, $dns_servers, $dns_name);
        if (defined($ip)) {
            $ad_server_host = $ad_fqdn;
            $ad_server_ip = $ip;
        }
        else {
            if (defined($ad_server) && valid_ip($ad_server)) {
                $ad_server_host = $ad_fqdn;
                $ad_server_ip = $ad_server;
            }
            else {
                return $self->render_error(422, "Unable to resolve AD FQDN: '$ad_fqdn' with given DNS server: '$dns_servers'\n");
            }
        }
    }
    else {
        $ad_server_host = $ad_fqdn;
        $ad_server_ip = $ad_server;
    }
    if (!valid_ip($ad_server_ip)) {
        return $self->render_error(422, "Unable to determine AD server's IP address\n")
    }

    my $api_host = $Config{'services_host'}{'pfconnector_service_host'};
    my $api_port = $old_item->{ntlm_auth_port} + JOIN_REMOTE_PORT_OFFSET;

    # For connector-backed domains, reach ntlm-join-remote through an on-demand
    # dynreverse tunnel (see connector_join_endpoint / create()).
    if ($use_connector && !is_nt_hash_pattern($new_data->{machine_account_password})) {
        my $err_msg;
        ($api_host, $api_port, $err_msg) = $self->connector_join_endpoint($ad_server_ip);
        if (defined($err_msg)) {
            return $self->render_error(422, $err_msg);
        }
    }

    my @real_computer_names = ($real_computer_name);

    if ($additional_machine_accounts + 0 > 0) {
        for my $i (0 .. $additional_machine_accounts - 1) {
            if (length("$real_computer_name-$i") > 19) {
                return $self->render_error(422, "In order to create additional machine accounts, the base computer account is limited to maximum 16 characters. currently using '$real_computer_name', " + length($real_computer_name), " characters.")
            }
            push(@real_computer_names, "$real_computer_name-$i");
        }
    }
    for (my $i = 0; $i < @real_computer_names; $i++) {
        $real_computer_name = $real_computer_names[$i];
        if (!is_nt_hash_pattern($new_data->{machine_account_password})) {
            my ($add_status, $add_result) = pf::domain::dispatch_add_computer($use_connector, $api_host, $api_port, "-delete", $real_computer_name, $computer_password, $ad_server_ip, $ad_server_host, $dns_name, $workgroup, $ou, $bind_dn, $bind_pass, $force_ldap, \%ssl_options);
            if ($add_status == $FALSE) {
                unless ($add_result =~ /Account (.+) not found in/) {
                    $self->render_error(422, "Unable to update - remove existing machine account with following error: $add_result");
                    return 0;
                }
            }

            ($add_status, $add_result) = pf::domain::dispatch_add_computer($use_connector, $api_host, $api_port, " ", $real_computer_name, $computer_password, $ad_server_ip, $ad_server_host, $dns_name, $workgroup, $ou, $bind_dn, $bind_pass, $force_ldap, \%ssl_options);
            if ($add_status == $FALSE) {
                $self->render_error(422, "Unable to add machine account with following error: $add_result");
                return 0;
            }
            $new_data->{ou} = $new_item->{ou}
        }
        else {
            $new_data->{ou} = $old_item->{ou}
        }
    }
    $new_data->{machine_account_password} = md4_hex(encode("utf-16le", $new_data->{machine_account_password}));

    $new_data->{server_name} = $computer_name;
    delete $new_data->{id};
    delete $new_data->{bind_dn};
    delete $new_data->{bind_pass};
    my $id = $self->id;
    $cs->update($id, $new_data);
    return unless ($self->commit($cs));
    $self->post_update($id);
    $self->reprovision_connector_static($ad_server_ip) if $use_connector;
    $self->render(status => 200, json => $self->update_response($form));
}

sub update_response {
    my ($self, $form) = @_;
    my $id = $self->id;
    $id =~ s/^\S+\s+//;
    my %response = (message => "Settings updated", id => $id);
    for my $field ($form->fields) {
        my $type = $field->type;
        if (($type ne 'PathUpload' && $type ne 'Path') || $field->noupdate) {
            next;
        }

        $response{$field->accessor} = $field->value;
    }
    return $self->addFormWarnings($form, \%response);
}

sub remove {
    my ($self) = @_;
    my ($status, $msg, $errors) = $self->can_delete();
    if (is_error($status)) {
        return $self->render_error($status, $msg, $errors);
    }

    my $id = $self->id;
    my $cs = $self->config_store;
    ($msg, my $deleted) = $cs->remove($id, 'id');
    if (!$deleted) {
        return $self->render_error(422, "Unable to delete $id - $msg");
    }

    return unless ($self->commit($cs));
    $id =~ s/^\S+\s+//;
    return $self->render(json => { message => "Deleted $id successfully" }, status => 200);
}

sub is_nt_hash_pattern {
    my ($password) = @_;
    $password =~ s/^\s+|\s+$//g;
    if ($password =~ /[a-fA-F0-9]{32}/) {
        return 1;
    }
    return 0;
}

=head2 connector_join_endpoint

Resolve the host:port to reach the ntlm-join-remote service through the connector
that owns the given AD server IP. Sets up (or reuses) a dynreverse tunnel on the
fly, so no static tunnel or connector reconnect is required before a domain can be
joined. Returns ($host, $port, undef) on success or (undef, undef, $error_message)
when no connector matches the AD server IP or the connector is not reachable.

=cut

sub connector_join_endpoint {
    my ($self, $ad_server_ip) = @_;
    my $connector = pf::factory::connector->for_ip($ad_server_ip);
    unless (defined($connector) && defined($connector->id) && $connector->id ne 'local_connector') {
        return (undef, undef, "No connector matches the AD server IP '$ad_server_ip'. Ensure the domain's ad_server falls within a connector's configured networks.");
    }

    my $to = JOIN_REMOTE_TARGET_HOST . ":" . JOIN_REMOTE_TARGET_PORT . "/tcp";
    my $conn = eval { $connector->dynreverse($to, { pod_direct => 1 }) };
    if ($@) {
        get_logger->error("Failed to obtain dynreverse tunnel to ntlm-join-remote via connector '" . $connector->id . "': $@");
        return (undef, undef, "Unable to reach the connector '" . $connector->id . "' to set up the domain-join tunnel. Verify the connector is connected. ($@)");
    }
    unless (ref($conn) eq 'HASH' && $conn->{host} && $conn->{port}) {
        return (undef, undef, "The connector '" . $connector->id . "' did not return a usable domain-join tunnel endpoint.");
    }

    return ($conn->{host}, $conn->{port}, undef);
}

=head2 reprovision_connector_static

After committing a connector-backed domain, ask the owning connector's
pfconnector server to bind the domain's newly-added static tunnels (e.g. the
NTLM-auth tunnel on port ntlm_auth_port+CONNECTOR_PORT_OFFSET) on the live
tunnel, so the domain is usable without a manual connector reconnect.
Best-effort — never blocks the API response on connector reachability.

=cut

sub reprovision_connector_static {
    my ($self, $ad_server_ip) = @_;
    my $connector = pf::factory::connector->for_ip($ad_server_ip);
    return unless defined($connector) && defined($connector->id) && $connector->id ne 'local_connector';
    $connector->reprovision_static();
    return;
}

=head2 validate_input

validate_input

=cut

sub validate_input {
    my ($sel, $data) = @_;

    my $bind_dn = $data->{username};
    my $bind_pass = $data->{password};
    my @errors;
    if (!defined $bind_dn || length($bind_dn) == 0) {
        push @errors, { message => 'field username is required', field => 'username' },
    }

    if (!defined $bind_pass || length($bind_pass) == 0) {
        push @errors, { message => 'field password is required', field => 'password' },
    }

    if (@errors) {
        return 422, { message => 'username and or password missing', errors => \@errors };
    }

    return 200, { bind_dn => $bind_dn, bind_pass => $bind_pass };
}


=head2 fields_to_mask

fields_to_mask

=cut

sub fields_to_mask {qw(bind_pass password)}

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
