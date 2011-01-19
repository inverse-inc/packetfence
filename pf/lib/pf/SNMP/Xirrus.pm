package pf::SNMP::Xirrus;

=head1 NAME

pf::SNMP::Xirrus - Object oriented module to parse SNMP traps and manage Xirrus Wireless Access Points

=head1 SYNOPSIS

The pf::SNMP::Xirrus module implements an object oriented interface to manage Xirrus Wireless Access Points.

=head1 STATUS

Developed and tested against XS4 model ArrayOS version 3.5-724.

According to Xirrus engineers, this modules should work on any XS and XN model.

=head1 BUGS AND LIMITATIONS

SNMPv3 support is untested.

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP');
use POSIX;
use Log::Log4perl;
use pf::util;

=head1 SUBROUTINES

TODO: this list is incomplete

=over

=item getVersion

obtain image version information from switch

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

    # sysDescr sample output:
    #Xirrus XS4 WiFi Array
    #, ArrayOS Version 3.5-724

    if ( $sysDescr =~ m/Version (\d+\.\d+-\d+)/ ) {
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

=item deauthenticateMac

deauthenticate a MAC address from wireless network (including 802.1x)

=cut
sub deauthenticateMac {
    my ($this, $mac) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    my $OID_stationDeauthMacAddress = '1.3.6.1.4.1.21013.1.2.22.3.0'; # from XIRRUS-MIB

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't write to the stationDeauthMacAddress");
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    $logger->trace("SNMP set_request for stationDeauthMacAddress: $OID_stationDeauthMacAddress");
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_stationDeauthMacAddress",
            Net::SNMP::OCTET_STRING,
            $mac
        ] );

    # TODO: validate result
    $logger->info("deauthenticate mac $mac from access point : " . $this->{_ip});
    return ( defined($result) );

}

=item extractSsid

Find RADIUS SSID parameter out of RADIUS REQUEST parameters

Xirrus specific parser. See pf::SNMP for base implementation.

=cut
sub extractSsid {
    my ($this, $radius_request) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # it's put in Called-Station-Id
    # ie: Called-Station-Id = "aa-bb-cc-dd-ee-ff:Secure SSID"
    if (defined($radius_request->{'Called-Station-Id'})) {
        if ($radius_request->{'Called-Station-Id'} =~ /^
            [a-f0-9]{2}-[a-f0-9]{2}-[a-f0-9]{2}-[a-f0-9]{2}-[a-f0-9]{2}-[a-f0-9]{2}   # MAC Address
            :                                                                         # : delimiter
            (.*)                                                                      # SSID
        $/ix) {
            return $1;
        } else {
            $logger->info("Unable to extract SSID of Called-Station-Id: ".$radius_request->{'Called-Station-Id'});
        }
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

Copyright (C) 2009-2011 Inverse inc.

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
