package pf::Switch::Xirrus::AP_http;

=head1 NAME

pf::Switch::Xirrus::AP_http

=head1 SYNOPSIS

The pf::Switch::Xirrus::AP_http module implements an object oriented interface to 
manage the external captive portal on Xirrus access points

=head1 STATUS

Developed and tested on XR4430 running 6.4.1

=cut

use strict;
use warnings;

use base ('pf::Switch::Xirrus');
use Log::Log4perl;

use pf::config;
use pf::util;
use pf::node;

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessMacAuth { return $TRUE; }
sub supportsExternalPortal { return $TRUE; }
sub supportsWebFormRegistration { return $TRUE }

=item parseUrl

This is called when we receive a http request from the device and return specific attributes:

client mac address
SSID
client ip address
redirect url
grant url
status code

=cut

sub parseUrl {
    my($this, $req, $r) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $connection = $r->connection;
    $this->synchronize_locationlog("0", "0", clean_mac($$req->param('mac')),
        0, $WIRELESS_MAC_AUTH, clean_mac($$req->param('mac')), $$req->param('ssid')
    );
    return (clean_mac($$req->param('mac')),$$req->param('ssid'),$connection->remote_ip,$$req->param('userurl'),undef,"200");
}

sub parseSwitchIdFromRequest {
    my($class, $req) = @_;
    my $logger = Log::Log4perl::get_logger( $class );
    return $$req->param('nasid'); 
}

=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Overriding the default implementation for the external captive portal

=cut

sub returnRadiusAccessAccept {
    my ($self, $vlan, $mac, $port, $connection_type, $user_name, $ssid, $wasInline, $user_role) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    my $radius_reply_ref = {};

    my $node = node_view($mac);

    my $violation = pf::violation::violation_view_top($mac);
    # if user is unregistered or is in violation then we reject him to show him the captive portal 
    if ( $node->{status} eq $pf::node::STATUS_UNREGISTERED || defined($violation) ){
        $logger->info("$mac is unregistered. Refusing access to force the eCWP");
        my $radius_reply_ref = {
            'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
            'Tunnel-Type' => $RADIUS::VLAN,
            'Tunnel-Private-Group-ID' => -1,
        }; 
        return [$RADIUS::RLM_MODULE_OK, %$radius_reply_ref]; 

    }
    else{
        $logger->info("Returning ACCEPT");
        return [$RADIUS::RLM_MODULE_OK, %$radius_reply_ref];
    }

}

sub getAcceptForm {
    my ( $self, $mac , $destination_url, $cgi_session) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    $logger->debug("Creating web release form for $mac");

    my $uamip = $cgi_session->param("ecwp-original-param-uamip");
    my $uamport = $cgi_session->param("ecwp-original-param-uamport");
    my $userurl = $cgi_session->param("ecwp-original-param-userurl");
    my $challenge = $cgi_session->param("ecwp-original-param-challenge");
    my $newchal  = pack "H32", $challenge;

    my @ib = unpack("C*", "\0" . $mac . $newchal);
    my $encstr = join("", map {sprintf('\%3.3o', $_)} @ib);
    my ($passvar) = split(/ /, `printf '$encstr' | md5sum`);

    $mac =~ s/:/-/g;

    my $html_form = qq[
        <script>
        if (document.URL.match(/res=success/)){
            //http requests are too fast for the ap
            //we leave him time to understand what is happening
            setTimeout(function(){window.location = "$destination_url"}, 2000)
        }
        else{
            window.location = "http://$uamip:$uamport/logon?username=$mac&password=$passvar&userurl=$destination_url"
        }
        </script>
    ];

    $logger->info($html_form);
    return $html_form;
}
=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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
