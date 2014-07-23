package pf::Switch::AeroHIVE::AP_http;

=head1 NAME

pf::Switch::AeroHIVE::AP_http - Object oriented module to AeroHIVE using the external captive portal

=head1 SYNOPSIS

The pf::Switch::AeroHIVE::AP module implements an object oriented interface to interact with the AeroHIVE captive portal

=head1 STATUS

Tested on an AP330 running HiveOS 6.1r6.1779

=cut

=head1 BUGS AND LIMITATIONS

=over

=item Redirect URL is not working

When selecting the option to redirect the user to the initially requested page, the AeroHIVE access point is not able to do the redirection properly.
Using the default success page of AeroHIVE works.

=back

=cut

use strict;
use warnings;
use Log::Log4perl;
use pf::config;
use pf::node;
use pf::violation;
use pf::locationlog;
use pf::util;

use base ('pf::Switch::AeroHIVE::AP');

sub description { 'AeroHIVE AP with web auth' }

sub supportsExternalPortal { return $TRUE; }
sub supportsWebFormRegistration { return $TRUE }

sub parseUrl {
    my($self, $req) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    # need to synchronize the locationlog event if we'll reject
    $self->synchronize_locationlog("0", "0", clean_mac($$req->param('Calling-Station-Id')),
        0, $WIRED_MAC_AUTH, clean_mac($$req->param('Calling-Station-Id')), $$req->param('ssid')
    );


    return ($$req->param('Calling-Station-Id'),$$req->param('ssid'),$$req->param('STA-IP'),$$req->param('destination_url'),$$req->param('url'),"200");

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
    my ( $self, $mac , $destination_url) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    $logger->debug("Creating web release form for $mac");

    my $node = node_view($mac);
    my $last_ssid = $node->{last_ssid};
    $mac =~ s/:/-/g;
    my $html_form = qq[
        <form name="weblogin_form" method="POST" action="http://1.1.1.1/reg.php">
            <input type="hidden" name="Submit2" value="Submit">
            <input type="hidden" name="autherr" value="0">
            <input type="hidden" name="username" value="$mac">
            <input type="hidden" name="password" value="$mac">
            <input type="hidden" name="ssid" value="$last_ssid">
            <input type="hidden" name="url" value="$destination_url">
        </form>
        <script language="JavaScript" type="text/javascript">
        window.setTimeout('document.weblogin_form.submit();', 1000);
        </script>
    ];

    $logger->info($html_form);
    return $html_form;
}

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

