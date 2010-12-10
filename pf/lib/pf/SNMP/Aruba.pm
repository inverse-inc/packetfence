package pf::SNMP::Aruba;

=head1 NAME

pf::SNMP::Aruba - Object oriented module to access SNMP enabled Aruba switches

=head1 SYNOPSIS

The pf::SNMP::Aruba module implements an object oriented interface
to access SNMP enabled Aruba switches.

=cut

=head1 BUGS AND LIMITATIONS

=over

=item The module currently doesn't work with Controllers in the MASTER / LOCAL configuration

This is caused by the fact that the client state is on the LOCAL controller but for PacketFence the IP who initiated the RADIUS authentication is the IP it talks to (which is the master and not the local).

=item Telnet deauthentication

Wireless deauthentication (deassociation) works only in Telnet

=back 

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP');
use POSIX;
use Log::Log4perl;
use Net::Telnet;
use pf::util;

=head1 SUBROUTINES

TODO: this list is incomplete

=over

=item getVersion - obtain image version information from switch

=cut
sub getVersion {
    my ($this)       = @_;
    my $oid_sysDescr = '1.3.6.1.2.1.1.1.0';
    my $logger       = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysDescr: $oid_sysDescr");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$oid_sysDescr] );
    my $sysDescr = ( $result->{$oid_sysDescr} || '' );
    if ( $sysDescr =~ m/V(\d{1}\.\d{2}\.\d{2})/ ) {
        return $1;
    } elsif ( $sysDescr =~ m/Version (\d+\.\d+\([^)]+\)[^,\s]*)(,|\s)+/ ) {
        return $1;
    } else {
        return $sysDescr;
    }
}

sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # wlsxNUserEntryDeAuthenticated: 1.3.6.1.4.1.14823.2.3.1.11.1.2.1017

    if ( $trapString =~ /\.1\.3\.6\.1\.4\.1\.14823\.2\.3\.1\.11\.1\.2\.1017[|].+[|]\.1\.3\.6\.1\.4\.1\.14823\.2\.3\.1\.11\.1\.1\.52\.[0-9]+ = Hex-STRING: ([0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2})/ ) {   
        $trapHashRef->{'trapType'}    = 'dot11Deauthentication';
        $trapHashRef->{'trapMac'}     = lc($1);
        $trapHashRef->{'trapMac'} =~ s/ /:/g;
    
    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

=item deauthenticateMac - deauthenticate a MAC address from wireless network (including 802.1x)

Here, we find out what submodule to call _dot1xDeauthenticateMAC or _deauthenticateMAC and call accordingly.

=cut
sub deauthenticateMac {
    my ( $this, $mac, $is_dot1x ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't write to the bnsMobileStationTable");
        return 1;
    }

    if ( !$this->connectRead() ) {
        $logger->error("Can not connect using SNMP to Aruba Controller " . $this->{_ip});
        return 1;
    }

    if ( length($mac) != 17 ) {
        $logger->error("MAC format is incorrect ($mac). Should be xx:xx:xx:xx:xx:xx");
        return 1;
    }

    if (defined($is_dot1x) && $is_dot1x) {
        $logger->debug("deauthenticate $mac using 802.1x deauth method");
        $this->_dot1xDeauthenticateMAC($mac);
    } else {
        # Any other authentication method lets kick out with traditionnal approach
        $logger->debug("deauthenticate $mac using non-802.1x deauth method");
        $this->_deauthenticateMAC($mac);
    }
}

# old code used to find user authentication method then kick him out accordingly, not required anymore
#use constant AUTH_DOT1X => 4;
#sub deauthenticateMac {
#    my ($this, $mac) = @_;
#    my $logger = Log::Log4perl::get_logger( ref($this) );
#    my $OID_nUserAuthenticationMethod = '1.3.6.1.4.1.14823.2.2.1.4.1.2.1.6'; # from WLSX-USER-MIB
#    ...
#    # Query the controller to get the type of authentication the user is using
#    $logger->trace("SNMP get_table for nUserAuthenticationMethod: $OID_nUserAuthenticationMethod");
#    my $result = $this->{_sessionRead}->get_table(-baseoid => "$OID_nUserAuthenticationMethod");
#    # is there at least one result?
#    if (keys %{$result}) {
#
#        # convert MAC into oid format
#        my $macOID = mac2oid($mac);
#
#        # Fetch Auth Method for the MAC we are interested in
#        my $count = 0;
#        foreach my $macIpToUserAuthMethod (keys %{$result}) {
#            if ($macIpToUserAuthMethod =~ /^$OID_nUserAuthenticationMethod\.$macOID/) {
#                if ($count > 1) {
#                    $logger->warn("MAC: $mac returned two authentication method, it should not happen!" .
#                                  " Please file a bug with steps to reproduce");
#                    return;
#                } else {
#                    if ($result->{$macIpToUserAuthMethod} == AUTH_DOT1X) {
#                        $logger->trace("using 802.1x deauth method");
#                        $this->_dot1xDeauthenticateMAC($mac);
#                    } else {
#                        # Any other authentication method lets kick out with traditionnal approach
#                        $logger->trace("using non-802.1x deauth method");
#                        $this->_deauthenticateMAC($mac);
#                    }
#                    $count++;
#                }
#           }
#        }  
#    } else {
#        $logger->error("was not able to find user authentication type for mac $mac, unable to deauthenticate");
#    }
#}

=item _dot1xDeauthenticateMAC - deauthenticate a MAC from controller when user is in 802.1x mode

* Private: don't call outside of same object, use deauthenticateMac externally *

=cut
sub _dot1xDeauthenticateMAC {
    my ($this, $mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    my $session = $this->getTelnetSession;
    if (!$session) {
        $logger->error("Can't connect to Aruba Controller ".$this->{'_ip'}." using ".$this->{_cliTransport});
        return;
    }

    my $cmd = "aaa user delete mac $mac";

    $logger->info("deauthenticating 802.1x $mac with `$cmd`");
    $session->cmd($cmd);

    $session->close();

}

=item _deauthenticateMAC - deauthenticate a MAC from controller if user is not in 802.1x mode

Here we used to specify MAC and IP in the OID but it doesn't work in a lot of 
cases. As soon as the client stops doing activity for a little while, the IP 
is forgotten but you can still access the good BSSID with 0.0.0.0 appended at 
the end of the OID (no IP).

What we are doing now is fetching the table instead of only one entry and
issuing deauth on the matching MAC in OID format. Worked in my tests with 
and without an IP in the table.

* Private: don't call outside of same object, use deauthenticateMac externally *

=cut
sub _deauthenticateMAC {
    my ($this, $mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    my $OID_nUserApBSSID = '1.3.6.1.4.1.14823.2.2.1.4.1.2.1.11'; # from WLSX-USER-MIB

    # Query the controller to get the MAC address of the AP to which the client is associated
    $logger->trace("SNMP get_table for nUserApBSSID: $OID_nUserApBSSID");
    my $result = $this->{_sessionRead}->get_table(-baseoid => "$OID_nUserApBSSID");
    if (keys %{$result}) {

        my $session = $this->getTelnetSession;
        if (!$session) {
            $logger->error("Can't connect to Aruba Controller ".$this->{'_ip'}." using ".$this->{_cliTransport});
            return;
        }

        # keep track of how many BSSID we grabbed for this MAC
        my $count = 0;

        # convert MAC into oid format
        my $macOID = mac2oid($mac);

        foreach my $macIpToBSSID (keys %{$result}) {
            if ($macIpToBSSID =~ /^$OID_nUserApBSSID\.$macOID/) { 
                # TODO: move over clean_mac or valid_mac?
                if ($result->{$macIpToBSSID} =~ /0x([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})/i) {
                    my $apSSID = uc("$1:$2:$3:$4:$5:$6");
                    my $cmd = "stm kick-off-sta $mac $apSSID";

                    $logger->info("deauthenticating $mac from SSID $apSSID with `$cmd`");
                    $session->cmd($cmd);
                    $count++;
                } else {
                    $logger->error("The MAC address format of the SSID is invalid: $macIpToBSSID");
                }
            }
        }

        $session->close();
        if ($count > 1) {
            $logger->warn("We deauthenticated more than one client with mac $mac");
        } elsif ($count == 0) {
            $logger->info("no one was deauthenticated (request with mac $mac)");
        }
    } else {
        $logger->error("Can not get AP SSID from Aruba Controller for MAC $mac");
        return;
    }
}

# TODO: extract in a more generic place?
sub getTelnetSession {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # use telnet to deauthenticate the client
    # FIXME: we do not honor the $this->{_cliTransport} parameter
    my $session;
    eval {
        $session = Net::Telnet->new(
            Host    => $this->{_ip},
            Timeout => 5,
            Prompt  => '/[\$%#>]$/'
        );
        $session->waitfor('/User: /');
        $session->put( $this->{_cliUser} . "\n" );
        $session->waitfor('/Password:/');
        $session->put( $this->{_cliPwd} . "\n" );
        $session->waitfor( $session->prompt );
        $session->put( "en\n" );
        $session->waitfor('/Password:/');
        $session->put( $this->{_cliEnablePwd} . "\n" );
        $session->waitfor( $session->prompt );
    };

    if ($@) {
        #$logger->error( Dumper($@));
        return;
    }

    return $session;
}

=item extractSsid

Find RADIUS SSID parameter out of RADIUS REQUEST parameters

Aruba specific parser. See pf::SNMP for base implementation.

=cut
sub extractSsid {
    my ($this, $radius_request) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # Aruba-Essid-Name VSA
    if (defined($radius_request->{'Aruba-Essid-Name'})) {
        return $radius_request->{'Aruba-Essid-Name'};
    }

    $logger->warn(
        "Unable to extract SSID for module " . ref($this) . ". SSID-based VLAN assignments won't work. "
        . "Please let us know so we can add support for it."
    );
    return;
}


=back

=head1 AUTHOR

Regis Balzard <rbalzard@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009,2010 Inverse inc.

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
