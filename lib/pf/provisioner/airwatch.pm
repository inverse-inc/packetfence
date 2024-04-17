package pf::provisioner::airwatch;
=head1 NAME

pf::provisioner::accept add documentation

=cut

=head1 DESCRIPTION

pf::provisioner::accept

=cut

use strict;
use warnings;
use List::MoreUtils qw(any);
use Moo;
use pf::log;
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON::MaybeXS qw(encode_json decode_json);
use Readonly;
use pf::constants;
use pf::util;
use pf::person;
use pf::node;
extends 'pf::provisioner';

=head2 protocol

Protocol to connect to the Airwatch web API

=cut

has protocol => (is => 'rw', required => 1, default => sub{"https"});

=head2 host

Host of the provisioner web API

=cut

has host => ( is => 'rw', required => $TRUE );

=head2 port

Port to connect to the provisioner web API

=cut

has port => ( is => 'rw', default => sub { $HTTPS_PORT } );

=head2 api_username

Username to connect to the API

=cut

has api_username => ( is => 'rw', required => $TRUE );

=head2 api_password

Password to connect to the API

=cut

has api_password => ( is => 'rw', required => $TRUE );

=head2 tenant_code

Tenant Code to connect to the API

=cut

has tenant_code => (is => 'rw', required => $TRUE);

=head2 sync_pid

Option to sync PID from provisioner

=cut

has sync_pid => (is => 'rw', required => 1);

Readonly::Scalar our $AIRWATCH_ENROLLED_STATUS => "Enrolled";

=head1 METHODS

=head2 authorize

always authorize user

=cut

sub authorize {
    my ($self, $mac) = @_;
    my $umac = uc($mac);
    $umac =~ s/://g;
    my $payload = {"BulkValues" => {"value" => [$umac]}};
    my ($status, $res) = $self->execute_request(POST($self->build_uri("/api/mdm/devices?searchby=Macaddress"), Content => encode_json($payload)));

    if($status != 200 && $status != 404) {
        get_logger->error("Failed get proper response from airwatch API. Status code '$status'. Response '$res'");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
    
    my $data = decode_json($res);

    if (!(defined($data->{Total}) && $data->{Total} == 1)) {
        return $FALSE;
    }

    my $device = $data->{Devices}[0];
    my $node_info = node_view($mac);
    if ($device->{EnrollmentStatus} eq $AIRWATCH_ENROLLED_STATUS) {
        if(isenabled($self->sync_pid) && $device->{UserName}) {
            my $pid = $device->{UserName};
            get_logger->info("Found username $pid through Airwatch");
            person_add($pid);
            node_modify($mac, pid => $pid);
        }

        return $self->handleAuthorizeEnforce(
            $mac,
            {
                node_info       => $node_info,
                airwatch        => $device,
                compliant_check => 1
            },
            $TRUE
        );
    }

    return $self->handleAuthorizeEnforce(
        $mac,
        {
            node_info => $node_info,
            airwatch => $device,
            compliant_check => 0,
        },
        $FALSE
    );
};

sub build_uri {
    my ($self, $path) = @_;
    return $self->protocol . "://" . $self->host . $path;
}

sub execute_request {
    my ($self, $request) = @_;
    my $ua = LWP::UserAgent->new();
    my $logger = get_logger;
    $request->authorization_basic($self->api_username, $self->api_password);
    $request->header( 'Content-Type' => 'application/json' );
    $request->header( 'Accept'       => 'application/json' );
    $request->header( 'aw-tenant-code' => $self->tenant_code );

    my $response = $ua->request($request);

    return ( $response->code, $response->decoded_content );
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
