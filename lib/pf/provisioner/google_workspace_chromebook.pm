package pf::provisioner::google_workspace_chromebook;

=head1 NAME

pf::provisioner::google_workspace_chromebook -

=head1 DESCRIPTION

pf::provisioner::google_workspace_chromebook

=cut

use strict;
use warnings;
use Moo;
extends 'pf::provisioner';
use JSON::MaybeXS qw( decode_json );
use pf::constants qw($default_pid $TRUE $FALSE);
use List::MoreUtils qw(any);
use List::Util qw(first);
use URI::Escape qw(uri_escape);
use pf::util qw(clean_mac);
use pf::log;
use pf::person qw(person_add);
use pf::node qw(node_register node_modify node_view);
use pf::security_event;
use fingerbank::Constant;
use WWW::Curl::Easy;
use pf::Curl;
use Crypt::JWT qw(encode_jwt);;
use LWP::UserAgent;
use CHI;
use Date::Parse qw(strptime);
our $CHI_CACHE = CHI->new(driver => 'RawMemory', datastore => {});

our $ACTIVE_STATUS = 'ACTIVE';

my $SCOPE = 'https://www.googleapis.com/auth/admin.directory.device.chromeos.readonly';

=head2 host

Host of google API

=cut

has host => (is => 'rw', default => sub { "www.googleapis.com" });

=head2 port

Port to connect to google API

=cut

has port => (is => 'rw', default =>  sub { 443 } );

=head2 protocol

Protocol to connect to google API.

=cut

has protocol => (is => 'rw', default => sub { "https" } );

=head2 service_account

service_account

=cut

has service_account => (is => 'rw', required => 1);

=head2 customer_id

customer_id

=cut

has customer_id => (is => 'rw', default => 'my_customer');

=head2 user

user

=cut

has user => (is => 'rw', required => 1);

=head2 _clock

A sub routine time

=cut

has _clock => (is => 'rw', default => sub { sub { time } } );

=head2 expires_in

expires_in

=cut

has expires_in => (is => 'rw', default => sub { 600 } );

=head2

expires_jiiter

=cut

has expires_jitter => (is => 'rw', default => sub { 10 } );

my $logger = get_logger();

sub process_devices {
    my ($self, $devices) = @_;
    for my $device (@$devices) {
        $self->process_device($device);
    }
}

sub cache {
    return pf::CHI->new(namespace => 'provisioning_distributed');
}

sub syncQueryKey {
    my ($self) = @_;
    return $self->id . ":syncQuery";
}

sub syncQuery {
    my ($self) = @_;
    my $syncQuery = $self->cache->get($self->syncQueryKey ) // "sync:0000-01-02..";
    return $syncQuery;
}

sub authorize {
    my ($self, $mac) = @_;
    my ($err, $device) = $self->getDevice($mac);
    if (defined $err) {
        return $err;
    }

    my $node_info = node_view($mac);
    if ($device->{status} eq $ACTIVE_STATUS) {
        my $recent_user = $self->getRecentUser($device);
        if (defined $recent_user) {
            person_add($recent_user);
            node_modify($mac, pid => $recent_user);
        }

        return $self->handleAuthorizeEnforce($mac, {node_info => $node_info, compliant_check => 1, google_workspace_chromebook => $device}, $TRUE);
    }

    return $self->handleAuthorizeEnforce($mac, {node_info => $node_info, compliant_check => 0, google_workspace_chromebook => $device}, $FALSE);
}

sub pollAndEnforce {
    my ($self, $timeframe) = @_;
    my $nextToken;
    my $query = $self->syncQuery;
    my $chromeosdevices;
    while (1) {
        my ( $err, $list ) = $self->getList(
            {
                pageToken => $nextToken,
                orderBy   => 'LAST_SYNC',
                query     => $query,
            }
        );
        if (defined $err) {
            $logger->error("Unable to contact the Google API to poll the changed devices.");
            return $err;
        }

        $chromeosdevices = $list->{chromeosdevices} // [];
        $self->process_devices($chromeosdevices);
        $nextToken = $list->{nextPageToken};
        last if !defined $nextToken;
    }

    if (defined $chromeosdevices && @$chromeosdevices) {
        $self->cache->set($self->syncQueryKey, syncDateToQuery($chromeosdevices->[-1]->{lastSync}));
    }
}

sub getNextImportDevices {
    my ($self, $nextToken) = @_;
    return $self->getList(
        {
            pageToken => $nextToken,
            orderBy   => 'LAST_SYNC',
            query     => $self->importLastSyncQuery()
        }
    );
}

sub importDevices {
    my ($self) = @_;
    my $nextToken;
    my $query = $self->importLastSyncQuery();
    while (1) {
        my ($err, $list) = $self->getNextImportDevices($nextToken);
        if (defined $err) {
            $logger->error("Unable to contact the Google API to import new devices.");
            return $err;
        }

        my $chromeosdevices = $list->{chromeosdevices} // [];
        $self->_import_devices($chromeosdevices);
        $nextToken = $list->{nextPageToken};
        last if !defined $nextToken;
    }
}

sub importLastSyncQuery {
    my ($self) = @_;
    return "sync:0000-01-01..";
}

sub _import_devices {
    my ($self, $chromeosdevices) = @_;
    for my $device (@$chromeosdevices) {
        $self->_import_device($device);
    }
}

sub _import_device {
    my ($self, $device) = @_;
    return if $device->{status} ne $ACTIVE_STATUS;
    my $role = $self->role_to_apply;
    my $user = $self->getRecentUser($device) // $default_pid;
    for my $f (qw(macAddress ethernetMacAddress ethernetMacAddress0)) {
        next if !exists $device->{$f};
        my $mac = $device->{$f};
        next if !defined $mac;
        node_register($mac, $user , category => $role );
    }
}

sub getRecentUser {
    my ($self, $device) = @_;
    my $recentUsers = $device->{recentUsers} // [];
    if (my $u = first { $_->{type} eq 'USER_TYPE_MANAGED' } @$recentUsers) {
        return $u->{email};
    }

    return undef;
}

sub syncDateToQuery {
    my ($date) = @_;
    my ($ss,$mm,$hh,$day,$month,$year,$zone) = strptime($date);
    return sprintf("sync:%04d-%02d-%02dT%02d:%02d:%02d..",$year+1900, $month+1,$day, $hh, $mm, $ss);
}

sub getDevice {
    my ($self, $mac) = @_;
    $mac =~ s/://g;
    my ($err, $list) = $self->getList( { query => $mac } );
    if (defined $err) {
        $logger->error($list);
        return $err, undef;
    }

    my $chromeosdevices = $list->{chromeosdevices} // [];
    if (@$chromeosdevices) {
        return undef, $chromeosdevices->[0];
    }

    return $FALSE, undef;
}

sub getList {
    my ($self, $options) = @_;
    my $url = $self->urlForList($options);
    my $curl = $self->curl($url);
    my $response_body;
    $curl->setopt(CURLOPT_WRITEDATA, \$response_body);
    my $curl_return_code = $curl->perform;
    my $response;

    # Looking at the results...
    if ( $curl_return_code == 0 ) {
        my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
        $response = decode_json($response_body);
        if($response_code == 200) {
            return undef, $response;
        }

        return $FALSE, $response_body;
    }

    my $msg = "An error occured while sending a JSONRPC request: $curl_return_code ".$curl->strerror($curl_return_code)." ".$curl->errbuf;
    return -1, $msg;;
}

sub curl {
    my ($self, $url) = @_;
    my $response_body = '';
    my $curl = pf::Curl::easy();
    $curl->setopt(CURLOPT_HEADER, 0);
    $curl->setopt(CURLOPT_URL, $url );
    $curl->setopt(CURLOPT_NOSIGNAL, 1);
    $curl->setopt(CURLOPT_NOPROGRESS, 1 );
    $curl->setopt(CURLOPT_DNS_USE_GLOBAL_CACHE, 0);
    return $curl;
}

sub process_device {
    my ($self, $device) = @_;
    for my $f (qw(macAddress ethernetMacAddress ethernetMacAddress0)) {
        if (!exists $device->{$f}) {
            next;
        }
        my $device_mac = $device->{$f};
        my $mac = clean_mac($device_mac);
        unless ($mac) {
            $logger->error("Mac given for $f ('$device_mac') is an invalid mac address");
            next;
        }

        $logger->debug("processing $mac");
        my $status = $device->{status};
        if ($status eq $ACTIVE_STATUS) {
            next;
        }

        if ($self->canAddSecurityEvent($mac, $device)) {
            my $non_compliance_security_event = $self->{non_compliance_security_event};
            pf::security_event::security_event_add($mac, $non_compliance_security_event);
        }
    }
}

sub canAddSecurityEvent {
    my ($self, $mac, $device) = @_;
    return 1;
}

sub supportsPolling {
    my ($self) = @_;
    return defined $self->{non_compliance_security_event};
}

=begin


=cut

sub baseUrl {
    my ($self) = @_;
    return $self->baseUri . "/admin/directory/v1/customer";
}

sub baseUri {
    my ($self) = @_;
    return $self->protocol . "://" . $self->host . ":" . $self->port
}

sub findByMac {
    my ($self, $mac) = @_;
    $mac =~ s/://g;
    my $url = $self->urlForList({ query => $mac});
    return;
}

=begin

GET https://www.googleapis.com/admin/directory/v1/customer/{my_customer|customer_id}/
devices/chromeos?projection={BASIC|FULL}&query=query
&orderBy=orderBy category&sortOrder={ASCENDING|DESCENDING}
&pageToken=token for next results page, if applicable
&maxResults=max number of results per page

=cut

my @options = qw(
    projection
    query
    orderBy
    sortOrder
    pageToken
    maxResults
    fields
);

sub urlForList {
    my ($self, $options) = @_;
    my $url = $self->baseUrl . "/" . $self->customer_id . "/devices/chromeos" ;
    my $access_token = $self->access_token;
    $url .= "?access_token=". uri_escape($access_token);
    for my $o (@options) {
        if (exists $options->{$o}) {
            my $v = $options->{$o};
            if (defined $v) {
                $url .= '&' . uri_escape($o) . "=" . uri_escape($v);
            }
        }
    }

    return $url;
}

sub access_token {
    my ($self) = @_;
    my $token = $self->get_cached_access_token;
    return $token->{access_token};
}

sub make_payload {
    my ($self, $scope) = @_;
    my $sa = $self->{service_account};
    my $iat = $self->_clock->();
    my $payload = {
        iss => $sa->{client_email},
        sub => $self->{user},
        scope => $scope,
        aud => $sa->{token_uri},
        exp => $iat + $self->expires_in,
        iat => $iat,
    };
}

sub get_cached_access_token {
    my ($self) = @_;
    my $id = $self->{id};
    my $token = $CHI_CACHE->get($id);
    if (defined $token) {
        return $token;
    }

    $token = $self->get_access_token;
    if (defined $token) {
        $CHI_CACHE->set($id, $token, $token->{expires_in} - $self->expires_jitter );
    }

    return $token;
}

sub get_access_token {
    my ($self) = @_;
    my $sa = $self->{service_account};
    my $payload = $self->make_payload($SCOPE);
    my $params = {
        grant_type => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion => encode_jwt(alg => 'RS256', payload => $payload, key => \$sa->{private_key}),
    };
    my $ua = LWP::UserAgent->new;
    my $response = $ua->post(
        $sa->{token_uri},
        $params,
    );

    if ($response->is_success) {
        my $data = decode_json($response->decoded_content);
        return $data;
    }

    return undef;
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
