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
extends 'pf::provisioner';

has protocol => (is => 'rw', required => 1, default => sub{"https"});
has host => (is => 'rw', required => 1);
has port => (is => 'rw', required => 1, default => sub{443});
has api_username => (is => 'rw', required => 1);
has api_password => (is => 'rw', required => 1);
has tenant_code => (is => 'rw', required => 1);

Readonly::Scalar our $AIRWATCH_ENROLLED_STATUS => "Enrolled";

=head1 METHODS

=head2 authorize

always authorize user

=cut

sub authorize {
    my ($self, $mac) = @_;

    $mac = "84:89:ad:84:08:cd";

    $mac = uc($mac);
    $mac =~ s/://g;
    my $payload = {"BulkValues" => {"value" => [$mac]}};
    my ($status, $res) = $self->execute_request(POST($self->build_uri("/api/mdm/devices?searchby=Macaddress"), Content => encode_json($payload)));

    if($status != 200 && $status != 404) {
        get_logger->error("Failed get proper response from airwatch API. Status code '$status'. Response '$res'");
        return $pf::provisioner::COMMUNICATION_FAILED;
    }
    
    my $data = decode_json($res);
    if(defined($data->{Total}) && $data->{Total} == 1 && $data->{Devices}->[0]->{EnrollmentStatus} eq $AIRWATCH_ENROLLED_STATUS) {
        return $TRUE;
    }
    else {
        return $FALSE;
    }
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

