package pf::provisioner::rest;
=head1 NAME

pf::provisioner::rest add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::rest

=cut

use strict;
use warnings;
use Moo;
extends 'pf::provisioner';

use WWW::Curl::Easy;
use JSON::MaybeXS qw( decode_json );
use pf::util qw(clean_mac);
use pf::log;
use pf::ip4log;
use pf::constants;
use MIME::Base64;
use pf::security_event;

=head1 Atrributes

=head2 username

Username of a user that has the API rights

=cut

has username => (is => 'rw');

=head2 password

Password of a user who has the API rights

=cut

has password => (is => 'rw');

=head2 host

Host of the rest web API

=cut

has host => (is => 'rw');

=head2 protocol

Protocol to connect to the web API

=cut

has protocol => (is => 'rw', default => sub { "https" } );

=head2 port

Port to connect to the JAMF web API

=cut

has port => ( is => 'rw', default => sub { $HTTPS_PORT } );

=head2 does_mac_exist

Check if the MAC address is present in the ServiceNow DB

=cut 

sub does_mac_exist{
    my ($self, $mac) = @_;
    my $logger = $self->logger;

    my $curl = WWW::Curl::Easy->new;
    my $url = $self->protocol.'://'.$self->host.":".$self->port.'/api/getVLANid/'.$mac;

    my $user_pass_base_64 = encode_base64("$self->{username}:$self->{password}", "");

    my $response_body = '';
    open(my $fileb, ">", \$response_body);
    $curl->setopt(CURLOPT_URL, $url );
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0) ;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_WRITEDATA,$fileb);
    $curl->setopt(WWW::Curl::Easy::CURLOPT_HTTPHEADER(),["Authorization: Basic $user_pass_base_64", 'Accept: application/json']);

    my $curl_return_code = $curl->perform;
    my $curl_info = $curl->getinfo(CURLINFO_HTTP_CODE); # or CURLINFO_RESPONSE_CODE depending on libcurl version


    if ($curl_info == 200) {
        my $infos = decode_json($response_body);
        foreach my $info (@{$infos}) {
            my $role = $info->{'iVLANid'};
            if (defined($role) && $role ne "") {
                return $role;
            }
        }

        $logger->error("MAC not found in the database");
        return 0;
    }
    elsif ($curl_info == 404){
        $logger->error("The URL used for the rest API seems invalid. Validate the configuration.");
        return $pf::provisioner::COMMUNICATION_FAILED;
    } else {
        $logger->error("There was an error validating $mac with rest. Got HTTP code $curl_info");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
}

sub validate_agent_installed{
    my ($self, $mac) = @_;
    my $logger = $self->logger;

    return 1;
}
 
sub authorize {
    my ($self,$mac) = @_;
    my $logger = $self->logger;
    my $ip = pf::ip4log::mac2ip($mac);
    $logger->info("Validating if $mac is compliant in rest");
    my $mac_exist = $self->does_mac_exist($mac);
    if ($mac_exist eq $pf::provisioner::COMMUNICATION_FAILED){
        return ($pf::provisioner::COMMUNICATION_FAILED, undef);
    }
    if ($mac_exist ne "0") {
        my $agent_install = $self->validate_agent_installed($mac_exist);
        if ($agent_install eq $pf::provisioner::COMMUNICATION_FAILED){
            return ($pf::provisioner::COMMUNICATION_FAILED, undef);
        }
        if ($agent_install ne "0") {
            return (1, $mac_exist);
        }
    } else {
        # Trigger security event
        if ($self->canAddSecurityEvent($mac)) {
            my $non_compliance_security_event = $self->{non_compliance_security_event};
            if (defined($non_compliance_security_event) && $non_compliance_security_event ne "") {
                pf::security_event::security_event_add($mac, $non_compliance_security_event);
            }
        }

        return (0, undef);
    }
}

=head2 logger

Return the current logger for the switch

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
}

sub canAddSecurityEvent {
    my ($self, $mac, $device) = @_;
    return 1;
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
