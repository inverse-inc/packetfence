package pf::SNMP::Netgear::GS110;

=head1 NAME

pf::SNMP::Netgear::GS110 - Object oriented module to access and configure enabled Netgear GS110 switches.

=head1 STATUS

=over

=item Link up/down

This switch only support links up/down SNMP enforcement

=back

=cut

use strict;
use warnings;

use Log::Log4perl;
use Net::SNMP;

use pf::SNMP::constants;

use base ('pf::SNMP::Netgear');

=head1 METHODS

=over

=item getVersion

=cut
sub getVersion {
    my ( $this ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $OID_version = "1.3.6.1.2.1.47.1.1.1.1.10.1";    # Provided by snmpbulkwalk the switch

    if ( !$this->connectRead() ) {
        return;
    }

    $logger->trace("SNMP get_request for OID_version: ( $OID_version )");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [
        "$OID_version"
    ] );
    $result = $result->{"$OID_version"};

    # Error handling
    if ( !defined($result) ) {
        $logger->warn("Asking for software version failed with " . $this->{_sessionRead}->error());
        return;
    }
    if ( !defined($result->{"$OID_version"}) ) {
        $logger->error("Returned value doesn't exists!");
        return;
    }
    if ( $result->{"$OID_version"} eq 'noSuchInstance' ) {
        $logger->warn("Asking for software version failed with noSuchInstance");
        return;
    }

    return $result->{"$OID_version"};
}

=item parseTrap

=cut
sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $trapHashRef;

    # link up/down traps
    if ( $trapString =~
            /BEGIN\ VARIABLEBINDINGS\ [^|]+[|]\.
            1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0               # SNMP notification
            \ =\ OID:\ \.                               
            1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])             # link UP(4) DOWN(3) trap
            \|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.([0-9]+)    # ifIndex
            /x ) {
        $trapHashRef->{'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;
    } 
    # unhandled traps
    else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }

    return $trapHashRef;
}

=item setAdminStatus

=cut
sub setAdminStatus {
    my ( $this, $ifIndex, $enabled ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $OID_ifAdminStatus = "1.3.6.1.2.1.2.2.1.7";    # ifMIB

    if ( !$this->isProductionMode() ) {
        $logger->info("The switch isn't in production mode (Do nothing): Should bounce ifIndex $ifIndex");
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return;
    }

    $logger->trace("SNNP set_request for OID_ifAdminStatus: ( $OID_ifAdminStatus.$ifIndex )");
    my $result = $this->{_sessionWrite}->set_request( -varbindlist => [
        "$OID_ifAdminStatus.$ifIndex", Net::SNMP::INTEGER, ( $enabled ? 1 : 2 )
    ] );
    if ( !defined($result) ) {
        $logger->error("Error bouncing ifIndex $ifIndex: " . $this->{_sessionWrite}->error);
    } else {
        $logger->info("Bouncing ifIndex $ifIndex");
    }

    return (defined($result));
}

=item _setVlan

=cut
sub _setVlan {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $OID_dot1qPvid = "1.3.6.1.2.1.17.7.1.4.5.1.1";    # Q-BRIDGE MIB

    if ( !$this->isProductionMode() ) {
        $logger->info("The switch isn't in production mode (Do nothing): Should set ifIndex $ifIndex to VLAN $newVlan");
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return;
    }

    $logger->trace("SNMP set_request for OID_dot1qPvid: ( $OID_dot1qPvid.$ifIndex u $newVlan )");
    my $result = $this->{_sessionWrite}->set_request( -varbindlist => [
        "$OID_dot1qPvid.$ifIndex", Net::SNMP::GAUGE, $newVlan
    ] );
    if ( !defined($result) ) {
        $logger->error("Error setting PVID $newVlan on ifIndex $ifIndex: " . $this->{_sessionWrite}->error);
    } else {
        $logger->info("Setting PVID $newVlan on ifIndex $ifIndex");
    }

    return (defined($result));
}

=back

=head1 AUTHOR

Derek Wuelfrath <dwuelfrath@inverse.ca>

Rich Graves <rgraves@carleton.edu>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

=head1 LICENCE

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
