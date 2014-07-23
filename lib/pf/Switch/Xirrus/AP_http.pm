package pf::Switch::Xirrus::AP_http;

=head1 NAME

pf::Switch::Xirrus::AP_http

=head1 SYNOPSIS

The pf::Switch::WirelessModuleTemplate module implements an object oriented interface to 
manage the external captive portal on Xirrus access points

=head1 STATUS

Developed and tested on XR4430 running 6.4.1

=cut

use strict;
use warnings;

use base ('pf::Switch');
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
        0, $WIRED_MAC_AUTH, clean_mac($$req->param('mac')), $$req->param('ssid')
    );
    return (clean_mac($$req->param('mac')),$$req->param('ssid'),$connection->remote_ip,$$req->param('userurl'),undef,"200");
}

sub parseSwitchIdFromRequest {
    my($class, $req) = @_;
    my $logger = Log::Log4perl::get_logger( $class );
    return $$req->param('nasid'); 
}

sub getAcceptForm {
    my ( $self, $mac , $destination_url) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );
    $logger->debug("Creating web release form for $mac");

    my $node = node_view($mac);
    my $last_ssid = $node->{last_ssid};
    $mac =~ s/:/-/g;
    my $html_form = qq[
        <form action="" method="POST">
        <table cellpadding="2" cellspacing="5" border="0">
            <input type="hidden" value="185.0.0.1" name="uamip">
            <input type="hidden" value="10000" name="uamport">
            <input type="hidden" value="" name="challenge">
            <tr>
              <td align="right"> Username:</td>
              <td><input name="UserName" type="text" size="50" maxlength="64" value="$mac"></td>
            </tr>
            <tr>
              <td align="right"> Password:</td>
              <td align="left"><input name="Password" type="password" size="50" maxlength="64" value="$mac"></td>
            </tr>
            <tr>
              <td align="right">&nbsp;</td>
              <td align="left"><input type="submit" name="button" class="button" value="Login"></td>
            </tr>
        </table>
        </form>
       
        
      
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
