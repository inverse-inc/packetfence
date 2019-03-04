package pf::provisioner::jamf;

=head1 NAME

pf::provisioner::jamf

=cut

=head1 DESCRIPTION

Allows to validate installation of management client using the JAMF API

=cut

use strict;
use warnings;

use Moo;
extends 'pf::provisioner';

use HTTP::Request::Common;
use JSON::MaybeXS qw(decode_json);
use LWP::UserAgent;
use Readonly;
use URI::Escape::XS qw(uri_escape);

use pf::constants;
use pf::error qw(is_error is_success);
use pf::log;
use pf::node;
use pf::util qw(isenabled);


Readonly our $JAMF_COMPUTERS_INVENTORY => 'computers';
Readonly our $JAMF_MOBILEDEVICES_INVENTORY => 'mobiledevices';


=head1 Atrributes

=head2 api_username

Username to connect to the API

=cut

has api_username => ( is => 'rw', required => $TRUE );

=head2 api_password

Password to connect to the API

=cut

has api_password => ( is => 'rw', required => $TRUE );

=head2 host

Host of the JAMF web API

=cut

has host => ( is => 'rw', required => $TRUE );

=head2 port

Port to connect to the JAMF web API

=cut

has port => ( is => 'rw', default => sub { $HTTPS_PORT } );

=head2 protocol

Protocol to connect to the JAMF web API

=cut

has protocol => ( is => 'rw', default => sub { $HTTPS } );

=head2 device_type_detection

Option to automacally detects device type

=cut

has device_type_detection => ( is => 'rw', default => sub { $FALSE } );

=head2 query_computers

Option to query the "computers" inventory

=cut

has query_computers => ( is => 'rw', default => sub { $TRUE } );

=head2 query_mobiledevices

Option to query the "mobile devices" inventory

=cut

has query_mobiledevices => ( is => 'rw', default => sub { $TRUE } );


=head1 Methods

=head2 authorize

Check whether the device exists or not in the JAMF API

=cut

sub authorize {
    my ( $self, $mac ) = @_;
    my $logger = get_logger;

    my ( $status, $device_type, $device_information ) = $self->get_device_information($mac);

    unless ( is_success($status) ) {
        $logger->info("Unable to complete a JAMF query for MAC address '$mac'");
        return $FALSE;
    }

    my $result = $self->parse_device_information($device_type, $device_information);

    if ( $result eq $TRUE ) {
        $logger->info("MAC address '$mac' seems to be managed by JAMF");
        return $TRUE;
    } else {
        $logger->info("MAC address '$mac' does not seems to be managed by JAMF");
        return $FALSE;
    }
}


=head2 get_device_information

=cut

sub get_device_information {
    my ( $self, $mac ) = @_;
    my $logger = get_logger;

    # JAMF API separates realms for "computers" and "mobiledevices" assets. Therefore, a different API call is required whether it is a computer or a mobile device.
    # To ease the configuration and the flow, different implementation options are offered:
    # - Automatically detect device type using Fingerbank
    # - Query both JAMF realms subsequently (query "computers" and if there is no answer, query "mobiledevices")
    # - Query only "computers" JAMF realm
    # - Query only "mobiledevices" JAMF realm
    my ( $status, $device_type, $device_information ) = 0;    # Initiating "status" to 0 not to trigger a success clause
    if ( isenabled($self->device_type_detection) ) {
        $device_type = $self->detect_device_type($mac);
        ( $status, $device_information ) = $self->execute_request($mac, $device_type) if defined $device_type;
    }
    unless ( is_success($status) ) {
        if ( isenabled($self->query_computers) ) {
            $device_type = $JAMF_COMPUTERS_INVENTORY;
            ( $status, $device_information ) = $self->execute_request($mac, $device_type);
        }
        if ( (isenabled($self->query_mobiledevices)) && (!is_success($status)) ) {
            $device_type = $JAMF_MOBILEDEVICES_INVENTORY;
            ( $status, $device_information ) = $self->execute_request($mac, $device_type);
        }
    }

    return ($status, $device_type, $device_information);
}


=head2 detect_device_type

Detects whether it is an Apple computer or an Apple Mobile device.

=cut

sub detect_device_type {
    my ( $self, $mac ) = @_;
    my $logger = get_logger;

    my $fingerbank_info = pf::node::fingerbank_info($mac);
    $fingerbank_info = $fingerbank_info->{'device_fq'};

    my $device_type;
    if ( $fingerbank_info =~ /iPod|iPhone|iPad/ ) {
        $device_type = $JAMF_MOBILEDEVICES_INVENTORY;
    }
    elsif ( $fingerbank_info =~ /Macintosh/ ) {
        $device_type = $JAMF_COMPUTERS_INVENTORY;
    }

    $logger->info("Detected a '$device_type' for MAC address '$mac' based of Fingerbank reply '$fingerbank_info'") if defined $device_type;

    return $device_type;
}


=head2 execute_request

Execute a request to the JAMF API

=cut

sub execute_request {
    my ( $self, $mac, $realm ) = @_;
    my $logger = get_logger;

    my $ua = LWP::UserAgent->new();
    my $request = GET $self->build_request_uri($mac, $realm);
    $request->authorization_basic($self->api_username, $self->api_password);
    $request->header( 'content-type' => 'application/json' );
    $request->header( 'Accept'       => 'application/json' );

    my $response = $ua->request($request);

    if ( $response->is_success ) {
        $logger->info("Successfully queried JAMF API for '$realm' with MAC address '$mac'");
    } else {
        $logger->info("Failure while querying JAMF API for '$realm' with MAC address '$mac'. Return code: '" . $response->status_line . "'");
    }

    return ( $response->code, $response->decoded_content );
}


=head2 build_request_uri

Build the request URI to be executed base of the MAC address and the JAMF realm

=cut

sub build_request_uri {
    my ( $self, $mac, $realm ) = @_;
    my $logger = get_logger;

    my $escaped_mac_address = uri_escape($mac);
    my $uri = $self->protocol . "://" . $self->host . "/JSSResource/" . $realm . "/macaddress/" . $escaped_mac_address;

    $logger->debug("Request to query: '$uri'");

    return $uri;
}


=head2 parse_device_information

=cut

sub parse_device_information {
    my ( $self, $device_type, $device_information ) = @_;
    my $logger = get_logger;

    my $json = decode_json($device_information);

    if ( $device_type eq $JAMF_COMPUTERS_INVENTORY ) {
        return $json->{'computer'}{'general'}{'remote_management'}{'managed'};
    }
    elsif ( $device_type eq $JAMF_MOBILEDEVICES_INVENTORY ) {
        return $json->{'mobile_device'}{'general'}{'managed'};
    }
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
