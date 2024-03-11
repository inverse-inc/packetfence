package pf::Switch::Bluesocket;


=head1 NAME

pf::Switch::Bluesocket

=head1 SYNOPSIS

The pf::Switch::Bluesocket module manages access to Bluesocket

=head1 STATUS

Should work on the Bluesocket version started 3.5.0

=cut

use strict;
use warnings;

use POSIX;
use Try::Tiny;
use HTTP::Request;
use JSON::MaybeXS;


use base ('pf::Switch');

use pf::file_paths qw($var_dir);
use pf::constants;
use pf::config qw(
    $MAC
    $SSID
);


use JSON::MaybeXS;

# The port to reach the Bluesocket controller API
our $API_PORT = "3000";

sub description { 'Bluesocket' }

# importing switch constants
use pf::Switch::constants;
use pf::util;

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
use pf::SwitchSupports qw(
    WirelessDot1x
    WirelessMacAuth
    RoleBasedEnforcement
);

# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }

=item getVersion - obtain image version information from switch

=cut

sub getVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    $logger->info("we don't know how to determine the version through SNMP !");
    return '3.5.0';
}

=head2 deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::HTTP;
    my %tech = (
        $SNMP::HTTP  => '_deauthenticateMacWithHTTP',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept response for the network device.

=cut


sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    $args->{'unfiltered'} = $TRUE;
    my @super_reply = @{$self->SUPER::returnRadiusAccessAccept($args)};
    my $status = shift @super_reply;
    my %radius_reply = @super_reply;
    my $radius_reply_ref = \%radius_reply;
    return [$status, %$radius_reply_ref] if($status == $RADIUS::RLM_MODULE_USERLOCK);

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=head2 _connect

Return the connection to the controller

=cut

sub _connect {
    my ($self) = @_;
    my $logger = $self->logger;

    my $controllerIp = $self->{_id};
    my $transport = lc($self->{_wsTransport});

    my $ua = LWP::UserAgent->new();
    $ua->cookie_jar({ file => "$var_dir/run/.bluesocket.cookies.txt" });
    $ua->ssl_opts(verify_hostname => 0);
    $ua->timeout(10);


    my $base_url = "$transport://$controllerIp:$API_PORT";

    return ($ua, $base_url);
}

=head2 _deauthenticateMacWithHTTP

Enable or disable the access of a user (portal vs no portal) using an HTTP webservices call

=cut

sub _deauthenticateMacWithHTTP {
    my ( $self, $mac ) = @_;
    my $logger = $self->logger;
    my $username = $self->{_wsUser};
    my $password = $self->{_wsPwd};

    my ($ua, $base_url)  = $self->_connect();

    # Create a request
    my $req = HTTP::Request->new(GET => "$base_url/active_user_statuses");
    $req->content_type('application/json');
    $req->header("Accept" => "application/json");

    $req->authorization_basic($username, $password);

    my $response = $ua->request($req);


    unless($response->is_success) {
        $logger->error("Can't have the active user status from the Bluesocket controller: ".$response->status_line);
        return;
    }

    my $json_data = decode_json($response->decoded_content());

    my @id;

    foreach my $entry (@{$json_data}) {

        if ($entry->{'active_user_status'}->{'macaddr'} eq $mac) {
            push (@id , $entry->{'active_user_status'}->{'id'});          
        }
    }

    my $data = {tableData => \@id};

    my $encoded_data = encode_json($data);

    $req->content($encoded_data);

    $req->method("DELETE");
    $req->uri("$base_url/active_user_statuses/multi_destroy");

    $response = $ua->request($req);

    unless($response->is_success) {
        $logger->error("Can't disconnect the device: ".$response->status_line);
        return;
    }

}


=item returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Filter-Id';
}



=back

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
