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
use Sys::Hostname;
use Socket;
use Digest::MD4 qw(md4_hex);
use Encode qw(encode);

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
    if (!defined $id || length($id) == 0) {
        $self->render_error(422, "Unable to validate", [{ message => "id field is required", field => 'id'}]);
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
    my $ad_server = $item->{ad_server};
    my $dns_name = $item->{dns_name};
    my $workgroup = $item->{workgroup};

    if ($computer_name eq "%h") {
        $computer_name = hostname();
        my ($first_element) = split(/\./, $computer_name);
        $computer_name = $first_element;
    }

    my $ad_server_host = "";
    my $ad_server_ip = "";

    if (valid_ip($ad_server)) {
        $ad_server_ip = $ad_server;
        $ad_server_host = gethostbyaddr(inet_aton($ad_server), AF_INET);
    }
    else {
        my $packed_ip = gethostbyname($ad_server);
        if (defined $packed_ip) {
            $ad_server_ip = inet_ntoa($packed_ip);
            $ad_server_host = $ad_server
        }
    }
    if ($ad_server_host eq "" || $ad_server_ip eq "") {
        return $self->render_error(422, "Unable to resolve hostname or IP of AD server '$ad_server'");
    }


    my $baseDN = $dns_name;
    my $domain_auth = "$workgroup/$bind_dn:$bind_pass";
    $baseDN = generate_baseDN($dns_name);

    my $add_result = pf::domain::add_computer(" ", $computer_name, $computer_password, $ad_server_ip, $ad_server_host, $baseDN, $workgroup, $domain_auth);

    my $encoded_password = encode("utf-16le", $computer_password);
    my $hash = md4_hex($encoded_password);
    $computer_password = $hash;

    if (!$add_result) {
        $self->render_error(422, "Unable to create machine account");
    }

    $cs->create($id, $item);
    return unless($self->commit($cs));
    $self->post_create($id);
    my $additional_out = $self->additional_create_out($form, $item);
    $self->stash( $self->primary_key => $id );
    $self->res->headers->location($self->make_location_url($id));
    $self->render(status => 201, json => $self->create_response($id, $additional_out));
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

sub test_join {
    my ($self) = @_;
    # Although a test_join will run relatively fast, it needs to run via pfqueue since pfperl-api is in a container and has to be restarted in order to be able to view the new netns namespaces
    # Once we get rid of the chroots/netns/samba design, this can go back to being a synchronous response
    my $client = pf::pfqueue::producer::redis->new();
    my $task_id = $client->submit("general", domain => {operation => "test_join", domain => $self->id}, undef, status_update => 1);
    $self->render(
        json => {
            "task_id" => $task_id,
        },
        status => 202,
    );
}

=head2 handle_domain_operation

Post a long running operation to the queue and render the task ID to follow its status

=cut

sub handle_domain_operation {
    my ($self, $op) = @_;
    my ($status, $json) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(status => $status, json => $json);
    }

    ($status, my $data) = $self->validate_input($json);
    if (is_error($status)) {
        return $self->render(status => $status, json => $data);
    }

    my $client = pf::pfqueue::producer::redis->new();
    my $task_id = $client->submit("general", domain => {%$data, operation => $op, domain => $self->id}, undef, status_update => 1);
    $self->render(
        json => {
            "task_id" => $task_id,
        },
        status => 202,
    );
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
        push @errors, {message => 'field username is required', field => 'username'},
    }

    if (!defined $bind_pass || length($bind_pass) == 0) {
        push @errors, {message => 'field password is required', field => 'password'},
    }

    if (@errors) {
        return 422, { message => 'username and or password missing' , errors => \@errors};
    }

    return 200, { bind_dn => $bind_dn, bind_pass => $bind_pass };
}

=head2 join

Join to the domain via the queue

=cut

sub join {
    my ($self) = @_;
    $self->handle_domain_operation("join");
}

=head2 unjoin

Unjoin to the domain via the queue

=cut

sub unjoin {
    my ($self) = @_;
    $self->handle_domain_operation("unjoin");
}

=head2 rejoin

Rejoin to the domain via the queue

=cut

sub rejoin {
    my ($self) = @_;
    $self->handle_domain_operation("rejoin");
}

=head2 fields_to_mask

fields_to_mask

=cut

sub fields_to_mask { qw(bind_pass password) }

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2023 Inverse inc.

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
