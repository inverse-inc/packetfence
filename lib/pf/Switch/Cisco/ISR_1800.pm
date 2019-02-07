package pf::Switch::Cisco::ISR_1800;

=head1 NAME

pf::Switch::Cisco::ISR_1800

=head1 SYNOPSIS

Object oriented module to parse SNMP traps and manage Cisco 1800 routers

=head1 STATUS

No documented minimum required firmware version. Lowest tested is 12.3(14)YT1.

Developed and tested on Cisco 1811 12.4(15)T6

=head1 BUGS AND LIMITATIONS

Version 12.4(24)T1, 12.4(15)T6 and 12.3(14)YT1 doesn't support VTP MIB or
BRIDGE-MIB in a comprehensive way.

Right now it needs CLI access to get the mac address table but that could be
resolved in the future with IOS 15.1T. See https://supportforums.cisco.com/message/3009429
for details.

SNMPv3 support was not tested.

SSH support is broken. You need to use Telnet.

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>


=head1 SUBROUTINES

=over

=cut

use strict;
use warnings;

use base ('pf::Switch::Cisco');
use Carp;
use Net::SNMP;

sub description { 'Cisco ISR 1800 Series' }

#sub getMinOSVersion {
#    my $self   = shift;
#    my $logger = $self->logger;
#    return '';
#}

# return the list of managed ports
#sub getManagedPorts {
#}

#obtain hashref from result of getMacAddr
#sub _getIfDescMacVlan {
#}

#sub clearMacAddressTable {
#}

#sub getMaxMacAddresses {
#}

sub isDefinedVlan {
    my ($self, $vlan) = @_;
    my $logger = $self->logger;

    # port assigned to VLAN (VLAN membership)
    my $oid_vmMembershipSummaryMemberPorts = "1.3.6.1.4.1.9.9.68.1.2.1.1.2"; #from CISCO-VLAN-MEMBERSHIP-MIB

    if ( !$self->connectRead() ) {
        return 0;
    }

    $logger->trace("SNMP get_request for vmMembershipSummaryMemberPorts: $oid_vmMembershipSummaryMemberPorts.$vlan");

    my $result = $self->{_sessionRead}->get_request( -varbindlist => ["$oid_vmMembershipSummaryMemberPorts.$vlan"] );

    return (
            defined($result)
            && exists( $result->{"$oid_vmMembershipSummaryMemberPorts.$vlan"} )
            && ($result->{"$oid_vmMembershipSummaryMemberPorts.$vlan"} ne 'noSuchInstance' )
    );
}

sub getVlan {
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;

    if (!$self->connectRead()) {
        return 0;
    }

    my $OID_vmVlan = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';    #CISCO-VLAN-MEMBERSHIP-MIB

    $logger->trace("SNMP get_request for vmVlan: $OID_vmVlan.$ifIndex");

    my $result = $self->{_sessionRead}->get_request( -varbindlist => ["$OID_vmVlan.$ifIndex"] );
    if (defined($result)
        && exists($result->{"$OID_vmVlan.$ifIndex"})
        && ($result->{"$OID_vmVlan.$ifIndex"} ne 'noSuchInstance')) {

        return $result->{"$OID_vmVlan.$ifIndex"};
    } else {
        $logger->error("Unable to get VLAN on ifIndex $ifIndex for ip: ".$self->{'ip'});
        return;
    }
}

=item getMacBridgePortHash

We need to override Cisco's implementation because BRIDGE-MIB is very limited on the 1811

Warning: this code doesn't support elevating to privileged mode. See #900 and #1370.

=cut

sub getMacBridgePortHash {
    my $self   = shift;
    my $vlan   = shift || '';
    my $logger = $self->logger;
    my %macBridgePortHash  = ();

    if ($vlan eq '') {
        $logger->error("Cannot query MAC table information on ".$self->{'_ip'}.": No VLAN provided");
        return %macBridgePortHash;
    }

    # before starting telnet let's get all the info we need
    my @ifIndexes = $self->_getAllIfIndexForThisVlan($vlan);
    my $ifDescrHashRef = $self->getAllIfDesc();

    my $session;
    eval {
        require Net::Appliance::Session;
        $session = Net::Appliance::Session->new(
            Host      => $self->{_ip},
            Timeout   => 5,
            Transport => $self->{_cliTransport}
        );
        $session->connect(
            Name     => $self->{_cliUser},
            Password => $self->{_cliPwd}
        );
    };

    if ($@) {
        $logger->error("Unable to connect to ".$self->{'_ip'}." using ".$self->{_cliTransport}.". Failed with $@");
        return %macBridgePortHash;
    }

    # Session not already privileged are not supported at this point. See #1370
    # are we in enabled mode?
    #if (!$session->in_privileged_mode()) {

    #    # let's try to enable
    #    if (!$session->enable($self->{_cliEnablePwd})) {
    #        $logger->error("Cannot get into privileged mode on ".$self->{'ip'}.
    #                       ". Are you sure you provided enable password in configuration?");
    #        $session->close();
    #        return %macBridgePortHash;
    #    }
    #}

    # command that allows us to get MAC to ifIndex information
    my $command = "show mac-address-table";

    $logger->trace("sending CLI command '$command'");
    my @output;
    eval { @output = $session->cmd(String => $command, Timeout => '10');};
    if ($@) {
        $logger->error("Error getting MAC Address table for ".$self->{'_ip'}.". Failed with $@");
        $session->close();
        return;
    }

    $logger->trace("output received:\n". join("\n",@output));

    foreach my $line (@output) {
        # Matching output like:
        # Destination Address  Address Type  VLAN  Destination Port
        # -------------------  ------------  ----  --------------------
        # 0003.47a5.09e8          Dynamic       1     FastEthernet6
        # 0007.e9e6.dbf2          Dynamic       1     FastEthernet6

        if ($line =~ /^
            ([0-9a-f]{2})([0-9a-f]{2})\.([0-9a-f]{2})([0-9a-f]{2})\.([0-9a-f]{2})([0-9a-f]{2}) # mac-address
            \s+\w+\s+\d+\s+ # stuff we don't care about
            (\w+)           # ifDescr
            \s*             # whitespace at the end
            $/x) {
            # if ifDescr is in @IfIndexes were are interested in, then add to MacBridgePortHash
            foreach my $ifIndex (keys %{$ifDescrHashRef}) {
                if ($ifDescrHashRef->{$ifIndex} eq $7 && grep(/$ifIndex/, @ifIndexes)) {
                    $macBridgePortHash{"$1:$2:$3:$4:$5:$6"} = $ifIndex;
                }
            }
        }
    }
    $session->close();
    return %macBridgePortHash;
}

=item _getAllIfIndexForThisVlan

Returns a list of all IfIndex part of a given VLAN

=cut

sub _getAllIfIndexForThisVlan {
    my ($self, $vlan) = @_;
    my $logger = $self->logger;

    if (!$self->connectRead()) {
        return 0;
    }

    my $OID_vmVlan = '1.3.6.1.4.1.9.9.68.1.2.2.1.2'; #from CISCO-VLAN-MEMBERSHIP-MIB

    $logger->trace("SNMP get_table for vmVlan: $OID_vmVlan");
    my @ifIndexes;
    my $result = $self->{_sessionRead}->get_table(-baseoid => $OID_vmVlan);
    foreach my $key (keys %{$result}) {
        # format matches and grab the ifIndex
        if ($key =~ /^$OID_vmVlan\.(\d+)$/) {
            # for the correct vlan
            if ($result->{$key} == $vlan) {
                push(@ifIndexes, $1);
            }
        }
    }
    return @ifIndexes;
}

=back

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

