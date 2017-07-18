package pf::provisioner::servicenow;
=head1 NAME

pf::provisioner::servicenow add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::servicenow

=cut

use strict;
use warnings;
use Moo;
extends 'pf::provisioner';

use WWW::Curl::Easy;
use JSON::MaybeXS qw( decode_json );
use pf::util qw(clean_mac);
use XML::Simple;
use pf::log;
use pf::ip4log;
use MIME::Base64;

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

Host of the servicenow web API
When it's in the cloud append the path to the instance
EX : mysetup.service-now.com/

=cut

has host => (is => 'rw');

=head2 table_for_mac

This is the table where the MAC are stored on your ServiceNow instance

=cut

has table_for_mac => (is => 'rw');

=head2 table_for_agent

This is the table where the agent are stored on your ServiceNow instance

=cut

has table_for_agent => (is => 'rw');

=head2 protocol

Protocol to connect to the web API

=cut

has protocol => (is => 'rw', default => sub { "https" } );


=head2 does_mac_exist

Check if the MAC address is present in the ServiceNow DB

=cut 

sub does_mac_exist{
    my ($self, $mac) = @_;
    my $logger = $self->logger;

    my $curl = WWW::Curl::Easy->new;
    my $url = $self->protocol.'://'.$self->host.$self->table_for_mac.'?JSONv2&sysparm_query=mac_address='.$mac;

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


    if ($curl_info == 200){
        my $info = decode_json($response_body);
        my $cmdb = $info->{records}[0]->{cmdb_ci};
        if (defined($cmdb) && $cmdb ne "0") {
            return $cmdb;
        } else {
            $logger->error("MAC not found in the database");
            return 0;
        }
    }
    elsif ($curl_info == 404){
        $logger->error("The URL used for the ServiceNow API seems invalid. Validate the configuration.");
        return $pf::provisioner::COMMUNICATION_FAILED;
    } else {
        $logger->error("There was an error validating $mac with ServiceNow. Got HTTP code $curl_info");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
}

sub validate_agent_installed{
    my ($self, $cmdb) = @_;
    my $logger = $self->logger;

    my $curl = WWW::Curl::Easy->new;
    my $url = $self->protocol.'://'.$self->host.$self->table_for_agent.'?JSONv2&sysparm_sys_id='.$cmdb;

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
        my $info = decode_json($response_body);
        my $installed_agent = $info->{records}[0]->{install_status};
        if (defined($installed_agent) && $installed_agent eq "1") {
            return 1;
        } else {
            $logger->error("The agent was not found on the device, moving it to isolation");
            return 0;
        }
    } elsif ($curl_info == 404){
        $logger->error("The URL used for the ServiceNow API seems invalid. Validate the configuration.");
        return $pf::provisioner::COMMUNICATION_FAILED;
    } else {
        $logger->error("There was an error validating with ServiceNow. Got HTTP code $curl_info");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
}

sub authorize {
    my ($self,$mac) = @_;
    my $logger = $self->logger;
    my $ip = pf::ip4log::mac2ip($mac);
    $logger->info("Validating if $mac is compliant in servicenow");
    my $mac_exist = $self->does_mac_exist($mac);
    if ($mac_exist ne "0") {
        $self->validate_agent_installed($mac_exist);
        return 1;
    } else {
        return 0;
    }

}

=head2 logger

Return the current logger for the switch

=cut

sub logger {
    my ($proto) = @_;
    return get_logger( ref($proto) || $proto );
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
