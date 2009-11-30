package pf::SNMP::Aruba;

=head1 NAME

pf::SNMP::Aruba - Object oriented module to access SNMP enabled Aruba switches

=head1 SYNOPSIS

The pf::SNMP::Aruba module implements an object oriented interface
to access SNMP enabled Aruba switches.

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP');
use POSIX;
use Log::Log4perl;
use Net::Telnet;

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
        $trapHashRef->{'trapIfIndex'} = "WIFI";
        $trapHashRef->{'trapMac'}     = lc($1);
        $trapHashRef->{'trapMac'} =~ s/ /:/g;
    
    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub deauthenticateMac {
    my ( $this, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_nUserApBSSID = '1.3.6.1.4.1.14823.2.2.1.4.1.2.1.11';

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

    # In order to deauthenticate a client we need to retrieve the SSID (actually it is the MAC address of the AP) to which it is connected.
    # We find this information in the nUserApBSSID entry of the WLSX-USER-MIB mib.
    # The entry looks like:
    # 1.3.6.1.4.1.14823.2.2.1.4.1.2.1.10.0.30.194.172.28.94.192.168.1.124 = STRING: 00:0b:86:cc:64:68';
    # which is actually:
    #        $OID_nUserApBSSID          .       mac        .      ip      = STRING: 00:0b:86:cc:64:68';

    #format MAC
    my @macArray = split( /:/, $mac );
    my $completeOid = $OID_nUserApBSSID;
    foreach my $macPiece (@macArray) {
        $completeOid .= "." . hex($macPiece);
    }

    # Add the client IP
    require pf::iplog;
    my $ip = pf::iplog::mac2ip($mac) || 0;
    if ($ip eq 0) {
        $logger->error("Can not find open entry in iplog for $mac");
        return 1;
    }
    $completeOid .= "." . $ip;

    # Query the controler to get the MAC address of the AP to which the client is associated
    $logger->trace("SNMP get_request for nUserApBSSID: $completeOid");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$completeOid] );
    if (defined($result)) {
        my $apSSID = $result->{$completeOid};
        if ($apSSID =~ /0x([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})/i) {
            $apSSID = uc("$1:$2:$3:$4:$5:$6");
        } else {
            $logger->error("The MAC address format of the SSID is invalid: $apSSID");
            return 1;
        }

        # use telnet to deauthenticate the client
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
            $logger->error("Can't connect to Aruba Controller ".$this->{'_ip'}." using ".$this->{_cliTransport});
            #$logger->error( Dumper($@));
            return 1;
        }

        my $cmd = "stm kick-off-sta $mac $apSSID";
        $logger->debug("deauthenticating $mac from SSID $apSSID with `$cmd`");
        $session->cmd($cmd);
        $session->close();
        return 1;
    } else {
        $logger->error("Can not get AP SSID from Aruba Controller for MAC $mac");
    }

}

=head1 AUTHOR

Regis Balzard <rbalzard@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009 Inverse inc.

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
