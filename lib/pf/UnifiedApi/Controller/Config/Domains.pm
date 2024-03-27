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
=head2 test_join

Test if a domain is properly joined

=cut

sub create {
    my ($self) = @_;
    my ($error, $item) = $self->get_json;
    if (defined $error) {
        return $self->render_error(400, "Bad Request : $error");
    }

    my $id = $item->{id};
    my $cs = $self->config_store;
    my $sections = $cs->readAllIds;
    my $max_port = 4999;
    for my $section (@$sections) {
        my $ntlm_auth_port = $cs->cachedConfig->val($section, "ntlm_auth_port");
        if (defined($ntlm_auth_port)) {
            if (int($ntlm_auth_port) > $max_port) {
                $max_port = $ntlm_auth_port;
            }
        }
    }
    $max_port = $max_port + 1;

    if (!defined $id || length($id) == 0) {
        $self->render_error(422, "Unable to validate", [ { message => "id field is required", field => 'id' } ]);
        return 0;
    }

    $item = $self->cleanupItemForCreate($item);
    (my $status, $item, my $form) = $self->validate_item($item);
    if (is_error($status)) {
        return $self->render(status => $status, json => $item);
    }

    $id = delete $item->{id} // $id;
    if ($cs->hasId($id)) {
        return $self->render_error(409, "An attempt to add a duplicate entry was stopped. Entry already exists and should be modified instead of created");
    }

    my $bind_dn = $item->{bind_dn};
    my $bind_pass = $item->{bind_pass};
    my $computer_name = $item->{server_name};
    my $computer_password = $item->{machine_account_password};
    my $ad_fqdn = $item->{ad_fqdn};
    my $ad_server = $item->{ad_server};
    my $dns_name = $item->{dns_name};
    my $workgroup = $item->{workgroup};
    my $real_computer_name = $item->{server_name};


    if ($computer_name eq "%h") {
        $real_computer_name = hostname();
        my @s = split(/\./, $real_computer_name);
        $real_computer_name = $s[0];
    }

    my $ad_server_host = "";
    my $ad_server_ip = "";

    my $dns_servers = $item->{dns_servers};
    if (defined($dns_servers)) {
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

    my $baseDN = $dns_name;
    my $domain_auth = "$workgroup/$bind_dn:$bind_pass";
    $baseDN = generate_baseDN($dns_name);

    my $ad_skip = delete $item->{ad_skip};
    if(!$ad_skip) {
        my ($add_status, $add_result) = pf::domain::add_computer(" ", $real_computer_name, $computer_password, $ad_server_ip, $ad_server_host, $baseDN, $workgroup, $domain_auth);
        if ($add_status == $FALSE) {
            if ($add_result =~ /already exists(.+)use \-no\-add/) {
                ($add_status, $add_result) = pf::domain::add_computer("-no-add", $real_computer_name, $computer_password, $ad_server_ip, $ad_server_host, $baseDN, $workgroup, $domain_auth);
                if ($add_status == $FALSE) {
                    $self->render_error(422, "Unable to add machine account with following error: $add_result");
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

    $item->{ntlm_auth_host} = '127.0.0.1';
    $item->{ntlm_auth_port} = $max_port;
    $item->{password_is_nt_hash} = '1';
    $item->{machine_account_password} = $computer_password;
    $item->{server_name} = $computer_name;

    delete $item->{bind_dn};
    delete $item->{bind_pass};

    $cs->create($id, $item);
    return unless ($self->commit($cs));
    $self->post_create($id);
    my $additional_out = $self->additional_create_out($form, $item);
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

    if ($computer_name eq "%h") {
        $real_computer_name = hostname();
        my @s = split(/\./, $real_computer_name);
        $real_computer_name = $s[0];
    }

    my $ad_server_host = "";
    my $ad_server_ip = "";

    my $dns_servers = $new_item->{dns_servers};
    if (defined($dns_servers)) {
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

    my $ad_skip = delete $item->{ad_skip};
    if(!$ad_skip) {
        if (($new_data->{machine_account_password} ne $old_item->{machine_account_password}) || ($computer_name eq "%h")) {
            my $baseDN = $dns_name;
            my $domain_auth = "$workgroup/$bind_dn:$bind_pass";
            $baseDN = generate_baseDN($dns_name);

            my ($add_status, $add_result) = pf::domain::add_computer("-no-add", $real_computer_name, $computer_password, $ad_server_ip, $ad_server_host, $baseDN, $workgroup, $domain_auth);
            if ($add_status == $FALSE) {
                if ($add_result =~ /Account.+not found in/) {
                    ($add_status, $add_result) = pf::domain::add_computer(" ", $real_computer_name, $computer_password, $ad_server_ip, $ad_server_host, $baseDN, $workgroup, $domain_auth);
                    if ($add_status == $FALSE) {
                        $self->render_error(422, "Unable to add machine account with following error: $add_result");
                        return 0;
                    }
                }
                else {
                    $self->render_error(422, "Unable to add machine account with following error: $add_result");
                    return 0;
                }
            }
            $new_data->{machine_account_password} = md4_hex(encode("utf-16le", $new_data->{machine_account_password}));
        }
    }

    $new_data->{server_name} = $computer_name;
    delete $new_data->{id};
    delete $new_data->{bind_dn};
    delete $new_data->{bind_pass};
    my $id = $self->id;
    $cs->update($id, $new_data);
    return unless ($self->commit($cs));
    $self->post_update($id);
    $self->render(status => 200, json => $self->update_response($form));
}

sub generate_baseDN {
    my $ret = "";

    my ($dns_name) = @_;
    my @array = split(/\./, $dns_name);

    foreach my $element (@array) {
        $ret .= "DC=$element,";
    }
    $ret =~ s/,$//;
    return $ret;
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

Copyright (C) 2005-2024 Inverse inc.

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
