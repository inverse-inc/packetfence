package pf::provisioner::intune;
=head1 NAME

pf::provisioner::intune add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::intune

=cut

use strict;
use warnings;
use Moo;
extends 'pf::provisioner';

use JSON::MaybeXS qw( decode_json );
use URI::Escape qw(uri_escape);
use pf::util qw(clean_mac);
use WWW::Curl::Easy;
use WWW::Curl::Form;
use pf::Curl;
use pf::constants;
use pf::log;
use pf::ip4log;
use pf::ConfigStore::Provisioning;
use DateTime::Format::RFC3339;
use pf::security_event;
use pf::node;

=head1 Atrributes

=head2 tenantID

tenant ID

=cut

has tenantID => (is => 'rw');

=head2 applicationID

Application ID

=cut

has applicationID => (is => 'rw');

=head2 applicationSecret

application Secret

=cut

has applicationSecret => (is => 'rw');


=head2 loginUrl

Host where to login to get the access token

=cut

has loginUrl => (is => 'rw', default => sub { "login.microsoftonline.com" });

=head2 host

Host of the Microsoft Graph web API

=cut

has host => (is => 'rw', default => sub { "graph.microsoft.com" });

=head2 port

Port to connect to the Microsoft Graph web API

=cut

has port => (is => 'rw', default =>  sub { 443 } );

=head2 protocol

Protocol to connect to the Microsoft Graph web API

=cut

has protocol => (is => 'rw', default => sub { "https" } );

=head2 access_token

The access token to be authorized on the Microsoft Graph web API

=cut

has access_token => (is => 'rw');

=head2 windows_agent_download_uri

URI to download the windows agent

=cut

has windows_agent_download_uri => (is => 'rw');

=head2 mac_osx_agent_download_uri

URI to download the Mac OSX agent

=cut

has mac_osx_agent_download_uri => (is => 'rw');

=head2 ios_agent_download_uri

URI to download the ios agent

=cut

has ios_agent_download_uri => (is => 'rw');

=head2 android_agent_download_uri

URI to download the Android agent

=cut

has android_agent_download_uri => (is => 'rw');

=head2 domains

Domains that needs to be allowed to fetch the agent

=cut

has domains => (is => 'rw');

=head2 device_lookup

Ordered list of the methods used to find the device in Intune (see
@DEVICE_LOOKUP_METHODS). Intune keeps a single Wi-Fi and a single Ethernet
MAC per device, so a MAC-only lookup misses docks, USB adapters and
secondary NICs (GitHub #9082); the other methods use identifiers PacketFence
already knows about the node.

=cut

has device_lookup => (is => 'rw', default => sub { ['mac'] });

=head1 Lookup methods

=over

=item azure_ad_device_id

The 802.1X identity (C<node.last_dot1x_username>) is the Azure AD / Entra
device ID. This is the case for EAP-TLS with an Intune SCEP profile whose
subject is C<CN={{AAD_Device_ID}}>. Graph: C<$filter=azureADDeviceId eq>.

=item intune_device_id

The 802.1X identity is the Intune managed device ID (C<CN={{DeviceId}}>).
Graph: C<managedDevices/{id}>.

=item device_name

The node's computer name (DHCP / Fingerbank) or the host name in the 802.1X
identity is the Intune device name. Graph: C<$filter=deviceName eq>.

=item mac

The historical behaviour: every managed device is listed and matched on
C<wiFiMacAddress> / C<ethernetMacAddress> (Graph cannot filter on those).

=back

=cut

our @DEVICE_LOOKUP_METHODS = qw(azure_ad_device_id intune_device_id device_name mac);
our $GRAPH_SELECT = '$select=id,deviceName,azureADDeviceId,serialNumber,wiFiMacAddress,ethernetMacAddress,complianceState,lastSyncDateTime';

sub get_access_token {
    my ($self) = @_;
    my $logger = get_logger();
    return $self->{'access_token'};
}

sub refresh_access_token {
    my ($self) = @_;
    my $logger = get_logger();

    my $curl = pf::Curl::easy();
    my $url = $self->protocol."://".$self->loginUrl.":".$self->port."/".$self->tenantID."/oauth2/token";

    my $response_body = '';
    open(my $fileb, ">", \$response_body);
    $curl->setopt(CURLOPT_URL, $url );
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0) ;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_WRITEDATA,$fileb);

    my $postdata = new WWW::Curl::Form;
    $postdata->formadd("client_id",$self->applicationID);
    $postdata->formadd("client_secret",$self->applicationSecret);
    $postdata->formadd("grant_type","client_credentials");
    $postdata->formadd("scope","https://graph.microsoft.com/Device.ReadWrite.All");
    $postdata->formadd("resource","https://graph.microsoft.com");

    $curl->setopt(CURLOPT_HTTPPOST, $postdata);

    my $curl_return_code = $curl->perform;
    my $curl_info = $curl->getinfo(CURLINFO_HTTP_CODE); # or CURLINFO_RESPONSE_CODE depending on libcurl version

    if ( $curl_return_code != 0 or $curl_info != 200 ) {
        # Failed to contact the Graph API.;
        $logger->error("Cannot connect to Graph to refresh the token");
        return $pf::provisioner::COMMUNICATION_FAILED;
    } else {
        my $json_response = decode_json($response_body);
        my $updated_config = {};
        my $access_token = $json_response->{'access_token'};
        if (defined $access_token && $access_token ne '') {
            $updated_config->{access_token} = $access_token;
            $self->{'access_token'} = $access_token;
        }
        else {
            $logger->error("Cannot update the access token for $self->{id}");
        }

        $self->update_config($updated_config);
        $logger->info("Refreshed the token to connect to the Graph API");
    }
}

=head2 update_config

Update the config for this provisioner

=cut

sub update_config {
    my ($self, $updated_config) = @_;
    my $cs     = pf::ConfigStore::Provisioning->new;
    my $config = $cs->read($self->{id});
    unless ($config) {
        get_logger->error("Error getting configuration for $self->{id}");
        return;
    }
    %$config = (%$config, %$updated_config);
    $cs->update($self->{'id'}, $config);
    return $cs->commit();
}

sub perform_get_device_info {
    my ($self, $url) = @_;
    my $logger = get_logger();

    unless ($self->get_access_token()) {
        $self->refresh_access_token();
    }
    my $access_token = $self->get_access_token();
    my $curl = pf::Curl::easy();

    $logger->debug("Calling Graph API using URL : ".$url);

    my $response_body = '';
    open(my $fileb, ">", \$response_body);
    $curl->setopt(CURLOPT_URL, $url );
    $curl->setopt(CURLOPT_SSL_VERIFYPEER, 0) ;
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_WRITEDATA,$fileb);
    $curl->setopt(WWW::Curl::Easy::CURLOPT_HTTPHEADER(), ['Content-Type: application/json', "Authorization: Bearer $access_token"]);

    my $curl_return_code = $curl->perform;
    my $curl_info = $curl->getinfo(CURLINFO_HTTP_CODE); # or CURLINFO_RESPONSE_CODE depending on libcurl version
    return $self->decode_response($curl_info, $response_body);
}

sub _is_comm_failed {
    my ($v) = @_;
    return defined $v && !ref($v) && $v eq $pf::provisioner::COMMUNICATION_FAILED;
}

sub graph_url {
    my ($self, $path) = @_;
    return $self->protocol . '://' . $self->host . ':' . $self->port . '/v1.0/deviceManagement/' . $path;
}

=head2 lookup_methods

The configured lookup methods, in order, restricted to the known ones.
Falls back to the MAC scan when nothing valid is configured.

=cut

sub lookup_methods {
    my ($self) = @_;
    my $configured = $self->device_lookup;
    my @methods = ref($configured) eq 'ARRAY' ? @$configured : split(/\s*,\s*/, $configured // '');
    my %known = map { $_ => 1 } @DEVICE_LOOKUP_METHODS;
    my (@valid, %seen);
    for my $m (map { lc } @methods) {
        push @valid, $m if $known{$m} && !$seen{$m}++;
    }
    return @valid ? @valid : ('mac');
}

=head2 normalize_dot1x_identity

Strips what 802.1X identities carry around the identifier itself: a
C<host/> prefix (machine authentication), a C<DOMAIN\> prefix and an
C<@realm> suffix.

=cut

sub normalize_dot1x_identity {
    my ($self, $identity) = @_;
    return undef unless defined $identity && length $identity;
    $identity =~ s/^host\///i;
    $identity =~ s/^[^\\]+\\//;
    $identity =~ s/@.*$//;
    $identity =~ s/^\s+|\s+$//g;
    return length $identity ? $identity : undef;
}

sub is_guid {
    my ($self, $value) = @_;
    return defined $value && $value =~ /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
}

sub short_hostname {
    my ($self, $name) = @_;
    return undef unless defined $name && length $name;
    $name =~ s/\..*$//;
    $name =~ s/\$$//;
    return length $name ? $name : undef;
}

=head2 lookup_identities

The identifier available for each lookup method, derived from the node.

=cut

sub lookup_identities {
    my ($self, $mac, $node_info) = @_;
    $node_info //= {};
    my %ids = (mac => $mac);
    my $identity = $self->normalize_dot1x_identity($node_info->{last_dot1x_username});
    if ($self->is_guid($identity)) {
        $ids{azure_ad_device_id} = lc $identity;
        $ids{intune_device_id}   = lc $identity;
    }
    my $name = $self->short_hostname($node_info->{computername});
    $name //= $self->short_hostname($identity) unless $self->is_guid($identity);
    $ids{device_name} = $name if defined $name;
    return \%ids;
}

=head2 find_device

Tries every configured lookup method in order and returns the first
managed device found, undef when none matched, or COMMUNICATION_FAILED.

=cut

sub find_device {
    my ($self, $mac, $node_info) = @_;
    my $logger = get_logger();
    my $ids = $self->lookup_identities($mac, $node_info);
    my @tried;
    for my $method ($self->lookup_methods) {
        my $value = $ids->{$method};
        unless (defined $value) {
            $logger->debug("Intune lookup by $method skipped for $mac: no identifier available on the node");
            next;
        }
        push @tried, "$method=$value";
        my $device = $self->find_device_by_method($method, $value);
        return $device if _is_comm_failed($device);
        if (defined $device) {
            $logger->info("Found device $mac in Intune by $method ($value): id=" . ($device->{id} // '?') . " name=" . ($device->{deviceName} // '?'));
            return $device;
        }
        $logger->debug("Device $mac not found in Intune by $method ($value)");
    }
    $logger->info("Device $mac not found in Intune (tried: " . (join(", ", @tried) || 'nothing, no identifier available') . ")");
    return undef;
}

sub find_device_by_method {
    my ($self, $method, $value) = @_;
    return $self->get_device_by_filter("azureADDeviceId eq '" . _odata_quote($value) . "'") if $method eq 'azure_ad_device_id';
    return $self->get_device_by_id($value)                                                   if $method eq 'intune_device_id';
    return $self->get_device_by_filter("deviceName eq '" . _odata_quote($value) . "'")      if $method eq 'device_name';
    return $self->get_device_by_mac($value)                                                  if $method eq 'mac';
    return undef;
}

# OData string literals escape a single quote by doubling it.
sub _odata_quote {
    my ($value) = @_;
    $value =~ s/'/''/g;
    return $value;
}

=head2 get_device_by_filter

Runs a C<$filter> query on managedDevices and returns the matching device;
when several match, the most recently synced one.

=cut

sub get_device_by_filter {
    my ($self, $filter) = @_;
    my $info = $self->perform_get_device_info($self->graph_url('managedDevices?' . $GRAPH_SELECT . '&$filter=' . uri_escape($filter)));
    return $info if _is_comm_failed($info);
    my @found = @{ (ref($info) eq 'HASH' ? $info->{value} : undef) // [] };
    return undef unless @found;
    if (@found > 1) {
        get_logger->warn("Intune returned " . scalar(@found) . " devices for filter '$filter'; using the most recently synced one");
        @found = sort { ($b->{lastSyncDateTime} // '') cmp ($a->{lastSyncDateTime} // '') } @found;
    }
    return $found[0];
}

sub find_device_by_mac {
    my ($self, $info, $mac) = @_;
    for my $entry (@{$info->{value} // []}) {
        if (($entry->{wiFiMacAddress} // "") eq $mac || ($entry->{ethernetMacAddress} // "") eq $mac) {
            return $entry;
        }
    }

    return undef;
}

=head2 get_device_by_id

Fetches one managed device by its Intune ID. Returns undef when Intune
does not know the ID (Graph answers 404 with an error document).

=cut

sub get_device_by_id {
    my ($self, $id) = @_;
    return undef unless defined $id && length $id;
    my $info = $self->perform_get_device_info($self->graph_url('managedDevices/' . uri_escape($id) . '?' . $GRAPH_SELECT));
    return $info if _is_comm_failed($info);
    return (ref($info) eq 'HASH' && defined $info->{id}) ? $info : undef;
}

=head2 get_device_by_mac

Lists every managed device (paged) and matches on the Wi-Fi / Ethernet MAC.
Graph does not filter on those properties, so this walks the whole fleet.

=cut

sub get_device_by_mac {
    my ($self, $mac) = @_;
    my $azuremac = uc($mac);
    $azuremac =~ s/://g;

    my $info = $self->perform_get_device_info($self->graph_url('managedDevices?' . $GRAPH_SELECT));
    return $info if _is_comm_failed($info);

    my $entry = $self->find_device_by_mac($info, $azuremac);
    return $entry if defined $entry;

    while ($info && !_is_comm_failed($info) && $info->{'@odata.nextLink'}) {
        $info = $self->perform_get_device_info($info->{'@odata.nextLink'});
        return $info if _is_comm_failed($info);
        $entry = $self->find_device_by_mac($info, $azuremac);
        return $entry if defined $entry;
    }

    return undef;
}

# Kept for callers of the historical name.
sub get_device_info {
    my ($self, $mac) = @_;
    return $self->get_device_by_mac($mac);
}

sub authorize {
    my ($self, $mac) = @_;
    my $logger = get_logger();
    my $node_info = node_view($mac);

    my $result = $self->find_device($mac, $node_info);
    if (_is_comm_failed($result)) {
        $logger->info("Graph access token is probably not valid anymore.");
        $self->refresh_access_token();
        $result = $self->find_device($mac, $node_info);
    }

    if (_is_comm_failed($result)) {
        $logger->error("Unable to contact the Graph API to validate if mac $mac is registered.");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }

    return $self->verify_compliance($mac, $result, $node_info);
}

sub verify_compliance {
    my ($self, $mac, $info, $node_info) = @_;
    my $logger = get_logger();
    $node_info //= node_view($mac);

    unless (ref($info) eq 'HASH' && defined $info->{id}) {
        # Not enrolled (or enrolled under identifiers we could not match):
        # not compliant, and there is no device record to hand to the rules.
        $logger->info("Device $mac is not enrolled in Intune (no managed device matched); treating it as non compliant.");
        if ($self->{non_compliance_security_event}) {
            pf::security_event::security_event_add($mac, $self->{non_compliance_security_event}, ());
        }
        return $self->handleAuthorizeEnforce($mac, {node_info => $node_info, compliant_check => 0, intune => undef}, $FALSE);
    }

    # The list/filter answers carry the selected properties only; fetch the
    # full record for the authorize_enforce rules.
    my $device = $self->get_device_by_id($info->{id});
    $device = $info unless ref($device) eq 'HASH';

    if (($info->{complianceState} // '') ne 'compliant') {
        $logger->info("Device $mac (Intune id $info->{id}) is not compliant: " . ($info->{complianceState} // 'unknown'));
        if ($self->{non_compliance_security_event}) {
            pf::security_event::security_event_add($mac, $self->{non_compliance_security_event}, ());
        }

        return $self->handleAuthorizeEnforce($mac, {node_info => $node_info, compliant_check => 0, intune => $device}, $FALSE);
    }

    $logger->info("Device $mac (Intune id $info->{id}) is compliant.");
    return $self->handleAuthorizeEnforce($mac, {node_info => $node_info, intune => $device, compliant_check => 1}, $TRUE);
}

sub decode_response {
    my ($self, $code, $response_body) = @_;
    my $logger = get_logger();
    if ( $code == 401 ) {
        $logger->error("Unauthorized to contact Graph");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
    elsif($code == 404) {
        $logger->info("Device is not in Graph Endpoint. Assuming device doesn't have the agent.");
        my $json_response = decode_json($response_body);
        return $json_response;
    }
    elsif($code != 200){
        $logger->error("Got error code $code when contacting the Graph API. Here's the response body : $response_body");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
    else {
        my $json_response = decode_json($response_body);
        return $json_response;
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
