package pf::Switch::Enterasys::Matrix_N3;

=head1 NAME

pf::Switch::Enterasys::Matrix_N3 - Object oriented module to parse SNMP traps and manage Enterasys Matrix N3 switches

=head1 STATUS

Developed and tested on a Matrix N3 Chassis with two slots: 7GR4270-12 (L3 / Router) and 7G4282-49 (L2 Switch). 
Firmware version: 5.42.10

It should work on all Matrix chassis.

=cut

use strict;
use warnings;
use Net::SNMP;
use base ('pf::Switch::Enterasys');

sub description { 'Enterasys Matrix N3' }

=head1 SUBROUTINES

=over

=item getMacBridgePortHash - return all MAC to ifIndex associations on a given vlan

We overload SNMP.pm's getMacBridgePortHash here because on this switch, the call returns MAC to dot1dBasePort 
associations. 
What we do here is the parent method and then translate dot1dBasePort to ifIndex.

=cut

sub getMacBridgePortHash {
    my $self   = shift;
    my $logger = $self->logger;
    my %macBridgePortHash = ();

    # call our parent method fill the hash with mac -> dot1dBasePort
    %macBridgePortHash = $self->SUPER::getMacBridgePortHash(@_);

    if ( !$self->connectRead() ) {
        return %macBridgePortHash;
    }

    # port associated to ifIndex
    my $oid_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #from BRIDGE-MIB

    $logger->trace("SNMP get_table for dot1dBasePortIfIndex: $oid_dot1dBasePortIfIndex");
    my $resultPortIfIndex = $self->{_sessionRead}->get_table(-baseoid => "$oid_dot1dBasePortIfIndex");

    # merging mac to port and port to ifIndex to get a mac to ifIndex hash
    foreach my $mac (keys %macBridgePortHash) {

        # dot1dBasePort
        my $port = $macBridgePortHash{$mac};

        # mac to ifIndex
        $macBridgePortHash{$mac} = $resultPortIfIndex->{$oid_dot1dBasePortIfIndex.".".$port};
    }
    if (! keys %macBridgePortHash) {
        $logger->warn("couldn't get MAC address list");
    }
    return %macBridgePortHash;
}

=item _setVlan - set the required vlan on the switch

=cut

# TODO: uses Q-BRIDGE-MIB in a conventional way, would be a candidate for a "setVlanUsingQbridgeMib" merge
# see http://www.packetfence.org/mantis/view.php?id=803 for details
sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;
    if (!$self->connectRead()) {
        return 0;
    }
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';                      # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticUntaggedPorts = '1.3.6.1.2.1.17.7.1.4.3.1.4';   # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticEgressPorts   = '1.3.6.1.2.1.17.7.1.4.3.1.2';   # Q-BRIDGE-MIB
    my $result;

    # translate ifIndex to dot1dBasePort
    my $dot1dBasePort = $self->getDot1dBasePortForThisIfIndex($ifIndex);
    if (!defined($dot1dBasePort)) {
        $logger->warn("unable to translate ifIndex into dot1dBasePort. Cannot set VLAN.");
        return 0;
    }

    {   
        my $lock = $self->getExclusiveLock();

        # get current egress and untagged ports
        $self->{_sessionRead}->translate(0);
        $logger->trace("SNMP get_request for dot1qVlanStaticUntaggedPorts and dot1qVlanStaticEgressPorts");
        $result = $self->{_sessionRead}->get_request(
            -varbindlist => [
                "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
                "$OID_dot1qVlanStaticEgressPorts.$newVlan",
                "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan",
                "$OID_dot1qVlanStaticUntaggedPorts.$newVlan"]
        );
        $self->{_sessionRead}->translate(1);

        # calculate new settings
        my $egressPortsOldVlan = $self->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticEgressPorts.$oldVlan"},
            $dot1dBasePort - 1, 0 );
        my $egressPortsVlan = $self->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticEgressPorts.$newVlan"},
            $dot1dBasePort - 1, 1 );
        my $untaggedPortsOldVlan = $self->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticUntaggedPorts.$oldVlan"},
            $dot1dBasePort - 1, 0 );
        my $untaggedPortsVlan = $self->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticUntaggedPorts.$newVlan"},
            $dot1dBasePort - 1, 1 );

        if (!$self->connectWrite()) {
            return 0;
        }

#        # set all values
#        $logger->trace("SNMP set_request for egressPorts and untaggedPorts for old and new VLAN");
#        $result = $self->{_sessionWrite}->set_request(
#            -varbindlist => [
#                "$OID_dot1qVlanStaticEgressPorts.$oldVlan", Net::SNMP::OCTET_STRING, $egressPortsOldVlan,
#                "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan", Net::SNMP::OCTET_STRING, $untaggedPortsOldVlan,
#                "$OID_dot1qVlanStaticEgressPorts.$newVlan", Net::SNMP::OCTET_STRING, $egressPortsVlan,
#                "$OID_dot1qVlanStaticUntaggedPorts.$newVlan", Net::SNMP::OCTET_STRING, $untaggedPortsVlan,
#                "$OID_dot1qPvid.$dot1dBasePort", Net::SNMP::GAUGE32, $newVlan]
#        );
#
#        if (!defined($result)) {
#            $logger->error("error setting egressPorts and untaggedPorts for old and new vlan: "
#                           .$self->{_sessionWrite}->error );
#        }

        # TODO: the following worked, now I could check if doing it in one pass still works (the above)
        #       this is known to work on other vendors and would be more efficient

        # remove port from oldVlan
        $logger->trace("SNMP set_request for egressPorts and untaggedPorts for old VLAN");
        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_dot1qVlanStaticEgressPorts.$oldVlan", Net::SNMP::OCTET_STRING, $egressPortsOldVlan,
                "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan", Net::SNMP::OCTET_STRING, $untaggedPortsOldVlan]
        );

        if (!defined($result)) {
            $logger->error("error setting egressPorts and untaggedPorts for old vlan: "
                           .$self->{_sessionWrite}->error );
        }

        # add port to newVlan and set port's PVID to newVlan
        $logger->trace("SNMP set_request for egressPorts and untaggedPorts for new VLAN");
        $result = $self->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_dot1qVlanStaticEgressPorts.$newVlan", Net::SNMP::OCTET_STRING, $egressPortsVlan,
                "$OID_dot1qVlanStaticUntaggedPorts.$newVlan", Net::SNMP::OCTET_STRING, $untaggedPortsVlan,
                "$OID_dot1qPvid.$dot1dBasePort", Net::SNMP::GAUGE32, $newVlan]
        );

        if (!defined($result)) {
            $logger->error("error setting egressPorts and untaggedPorts for new vlan: "
                           .$self->{_sessionWrite}->error );
        }

    }       
    $logger->trace("locking - \$switch_locker{".$self->{_ip}."} unlocked in _setVlan");
    return (defined($result));
}

# deprecated telnet method (left as a comment because it can still turn out to be useful)
# LIMITATION: only works with gigabit ports (ge.x.y)
#sub _setVlan {
#    my ($self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref) = @_;
#    my $logger = $self->logger;
#
#    # use telnet to set the new VLAN
#    my $session;
#    eval {
#        $session = Net::Telnet->new(
#            Host    => $self->{_ip},
#            Timeout => 5,
#            Prompt  => '/[\$%#>]$/' # prompt looks like: Matrix N3 Diamond(su)->
#        );
#        $session->waitfor('/Username: /');
#        $session->put( $self->{_cliUser} . "\n" );
#        $session->waitfor('/Password: /');
#        $session->put( $self->{_cliPwd} . "\n" );
#        $session->waitfor( $session->prompt );
#    };
#
#    if ($@) {
#        $logger->warn("Cannot connect to Enterasys Matrix N3 ".$self->{'_ip'}." using ".$self->{_cliTransport});
#        $logger->warn(Dumper($@));
#        return 0;
#    }
#
#    if ($ifIndex  =~ /(\d)\d{2}(\d{2})/) {
#        my $port = "ge.$1.$2";
#        my $cmd = "set port vlan $port $newVlan modify-egress";
#        $logger->debug("Changing VLAN on port $port with '$cmd'");
#        $session->cmd($cmd);
#        $session->close();
#        return 1;
#    } else {
#        $logger->warn("Unable to set new VLAN because I didn't understood ifIndex");
#    }
#}


=back

=head1 BUGS AND LIMITATIONS
    
SNMPv3 support was not tested.

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
