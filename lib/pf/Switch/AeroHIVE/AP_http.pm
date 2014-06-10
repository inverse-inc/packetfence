package pf::Switch::AeroHIVE::AP_web;

=head1 NAME

pf::Switch::AeroHIVE::AP - Object oriented module to access AP series via Telnet/SSH

=head1 SYNOPSIS

The pf::Switch::AeroHIVE::AP module implements an object oriented interface
to access AP  Series via Telnet/SSH

=head1 STATUS

This module is currently only a placeholder, see pf::Switch::AeroHIVE

=cut

use strict;
use warnings;
use Log::Log4perl;
use pf::config;

use base ('pf::Switch::AeroHIVE::AP');

sub description { 'AeroHIVE AP with web auth' }

sub supportsExternalPortal { return $TRUE; }
sub supportsWebFormRegistration { return $TRUE }

sub parseUrl {
    my($this, $req) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return ($$req->param('Calling-Station-Id'),$$req->param('ssid'),$$req->param('STA-IP'),$$req->param('destination_url'),$$req->param('url'),"200");

}

=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Overiding the default implementation for the external captive portal

=cut

sub returnRadiusAccessAccept {
    my ($self, $vlan, $mac, $port, $connection_type, $user_name, $ssid, $wasInline, $user_role) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    my $radius_reply_ref = {};

    my $node = node_view($mac);

    my $violation = violation_view_top($mac);
    # if user is unregistered or is in violation then we reject him to show him the captive portal 
    if( $node->{status} eq $STATUS_UNREGISTERED || defined($violation) ){
        $logger->info("$mac is unregistered. Refusing access to force the eCWP");
        return [$RADIUS::RLM_MODULE_REJECT, %$radius_reply_ref] 
    }
    else{
        $logger->info("Returning ACCEPT");
        return [$RADIUS::RLM_MODULE_OK, %$radius_reply_ref];
    }

}

sub getAcceptForm {
    my ( $self, $mac , $destination_url);

    my $node = node_view($mac);
    my $last_ssid = $node->{last_ssid}
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
        window.setTimeout('document.weblogin_form.submit();', 0.5 * 1000);
        </script>
    ];

}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

