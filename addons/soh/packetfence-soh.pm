#!/usr/bin/perl

=head1 NAME

pf-soh.pm - PacketFence integration with FreeRADIUS SoH support

=head1 DESCRIPTION

This module forwards SoH authorization requests to Packetfence.

=cut

use strict;
use warnings;
use Sys::Syslog;
use Try::Tiny;

# Configuration parameters
use constant {
    # FreeRADIUS to PacketFence communications (SOAP Server settings)
    WS_USER        => 'webservice',
    WS_PASS        => 'password',
    WEBADMIN_HOST  => 'localhost:1443',
    API_URI        => 'https://www.packetfence.org/PFAPI' #don't change this unless you know what you are doing
};
#Prevent error from LWP : ensure it connects to servers that have a valid certificate matching the expected hostname
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;

require 5.8.8;

# This is very important! Without this script will not get the filled hashes from FreeRADIUS.
our (%RAD_REQUEST, %RAD_REPLY, %RAD_CHECK);

#
# FreeRADIUS return values
#
use constant    RLM_MODULE_REJECT=>    0;#  /* immediately reject the request */
use constant    RLM_MODULE_FAIL=>      1;#  /* module failed, don't reply */
use constant    RLM_MODULE_OK=>        2;#  /* the module is OK, continue */
use constant    RLM_MODULE_HANDLED=>   3;#  /* the module handled the request, so stop. */
use constant    RLM_MODULE_INVALID=>   4;#  /* the module considers the request invalid. */
use constant    RLM_MODULE_USERLOCK=>  5;#  /* reject the request (user is locked out) */
use constant    RLM_MODULE_NOTFOUND=>  6;#  /* user not found */
use constant    RLM_MODULE_NOOP=>      7;#  /* module succeeded without doing anything */
use constant    RLM_MODULE_UPDATED=>   8;#  /* OK (pairs modified) */
use constant    RLM_MODULE_NUMCODES=>  9;#  /* How many return codes there are */

# when troubleshooting run radius -X and change the following line with: use SOAP::Lite +trace => qw(all), 
use SOAP::Lite
    # SOAP global error handler (mostly transport or server errors)
    # here we only log, the or on soap method calls will take care of returning
    on_fault => sub {   
        my($soap, $res) = @_;
        my $errmsg;
        if (ref $res && defined($res->faultstring)) {
            $errmsg = $res->faultstring;
        } else {
            $errmsg = $soap->transport->status;
        }
        syslog("info", "Error in SOAP communication with server: $errmsg");
        &radiusd::radlog(1, "PacketFence DENIED CONNECTION because of SOAP error see syslog for details.");
    };  

my $soap;

=head1 SUBROUTINES

Of interest to the PacketFence users / developers

=over

=item * authorize

This function is called to evaluate and react to an SoH packet. It is
the only callback available inside an SoH virtual server.

=cut

sub authorize {
    openlog("radiusd_pfsoh", "perror,pid", "user");

    my $code = RLM_MODULE_NOOP;
    try {
        $soap ||= SOAP::Lite->new(
            uri => API_URI,
            proxy => 'https://'.WS_USER.':'.WS_PASS.'@'.WEBADMIN_HOST.'/webapi'
        );

        my $som = $soap->soh_authorize(%RAD_REQUEST);
        die if $som->fault;

        my $result = $som->result();
        die unless ref $result eq 'ARRAY';

        $code = shift @$result;
        die unless $code && $code > 0 && $code < RLM_MODULE_NUMCODES;
    }
    catch {
        syslog("info", "SoH SOAP request failed: $_");
        $code = RLM_MODULE_FAIL;
        $soap = undef;
    }
    finally {
        closelog();
    };

    return $code;
}

=back

=head1 SEE ALSO

L<http://wiki.freeradius.org/Rlm_perl>

=head1 AUTHOR

Abhijit Menon-Sen <amenonsen@inverse.ca>

Based on packetfence.pm (from PacketFence's 802.1x addon).

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc. <support@inverse.ca>

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
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

=cut
