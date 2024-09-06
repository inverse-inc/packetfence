package pf::provisioner::kandji;
=head1 NAME

pf::provisioner::kandji add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::kandji

=cut

use strict;
use warnings;
use Moo;
extends 'pf::provisioner';

use pf::log;
use pf::provisioner;
use pf::constants;
use LWP::UserAgent;
use JSON::MaybeXS qw(decode_json);
use pf::error;
use pf::node;

=head1 Atrributes

=head2 api_token

API token to connect to the API

=cut

has api_token => (is => 'rw', required => $TRUE);

=head2 host

Host of the web API

=cut

has host => (is => 'rw', required => $TRUE);

=head2 port

Port to connect to the web API

=cut

has port => (is => 'rw', default => 443);

=head2 protocol

Protocol to connect to the web API

=cut

has protocol => (is => 'rw', default => "https");

=head2 enroll_url

The URL provided to end users so that they can enroll their devices (self-service enrollment portal of Kandji)
Defaults to $protocol://$host:$port/enroll if none is specified

=cut

has enroll_url => (is => 'rw', builder => 1, lazy => 1);

sub _build_enroll_url {
    my ($self) = @_;
    return $self->{enroll_url} || $self->protocol."://".$self->host.":".$self->port."/enroll"
}

sub api_url {
    my ($self, $path) = @_;
    return $self->protocol."://".$self->host.":".$self->port.$path;
}

sub get_lwp_client {
    my ($self, %args) = @_;
    my $ua = LWP::UserAgent->new(%args);

    $ua->default_header('Authorization' => 'Bearer '.$self->api_token);
    return $ua;
}

sub authorize {
    my ($self, $mac, $node_info) = @_;
    my $ua = $self->get_lwp_client();
    my $res = $ua->get($self->api_url("/api/v1/devices/?mac_address=$mac"));
    if($res->code != $STATUS::OK) {
        $self->logger->error("Failed to communicate with Kandji API: ", $res->status_line);
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
    
    my $data = decode_json($res->decoded_content);
    if (scalar(@$data) == 0) {
        $self->logger->info("$mac wasn't found in the Kandji inventory");
        return $FALSE;
    }

    if (scalar(@$data) > 1) {
        $self->logger->error("$mac was found multiple times in the Kandji inventory");
        return $FALSE;
    }

    $self->logger->info("$mac was found in the Kandji inventory, checking if agent is still installed and active");
    my $entry = $data->[0];
    $node_info = node_view($mac) if !defined $node_info;
    if ( !$entry->{agent_installed} || $entry->{is_missing} || $entry->{is_removed} ) {
        return $self->handleAuthorizeEnforce(
            $mac,
            {
                node_info       => $node_info,
                kandji          => $entry,
                compliant_check => 0
            },
            $FALSE
        );
    }

    return $self->handleAuthorizeEnforce(
        $mac,
        {
            node_info => $node_info,
            kandji => $entry,
            compliant_check => 1
        },
        $TRUE
    );
}

=head2 logger

Return the current logger for the provisioner

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
}

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
