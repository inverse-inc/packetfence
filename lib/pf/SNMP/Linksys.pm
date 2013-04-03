package pf::SNMP::Linksys;

=head1 NAME

pf::SNMP::Linksys - Object oriented module to access SNMP enabled Linksys
switches

=head1 SYNOPSIS

The pf::SNMP::Linksys module implements an object oriented interface
to access SNMP enabled Linksys switches.

=cut

use strict;
use warnings;

use base ('pf::SNMP');
use Log::Log4perl;
use Net::SNMP;
# disabling port-security since its known not to work
#use Net::Telnet;

sub getVersion {
    my ($this) = @_;
    my $oid_rlPhdUnitGenParamSoftwareVersion
        = '1.3.6.1.4.1.89.53.14.1.2.1';    #RADLAN-Physicaldescription-MIB
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace(
        "SNMP get_request for rlPhdUnitGenParamSoftwareVersion: $oid_rlPhdUnitGenParamSoftwareVersion"
    );
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => [$oid_rlPhdUnitGenParamSoftwareVersion] );
    if (exists( $result->{$oid_rlPhdUnitGenParamSoftwareVersion} )
        && ( $result->{$oid_rlPhdUnitGenParamSoftwareVersion} ne
            'noSuchInstance' )
        )
    {
        return $result->{$oid_rlPhdUnitGenParamSoftwareVersion};
    }
    return '';
}

sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->trace("matching trap string");
    if ( $trapString
        =~ /BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = INTEGER: \d+\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.7\.\d+ = INTEGER: [^|]+\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.8\.\d+ = INTEGER: [^(]+\((\d)\) END VARIABLEBINDINGS/
        )
    {
        $trapHashRef->{'trapType'} = ( ( $2 == 2 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $1;
    } elsif ( $trapString
        =~ /\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])\|\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = INTEGER: /i
        )
    {
        $trapHashRef->{'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;

    # disabling port-security since its known not to work
    #} elsif ( $trapString
    #    =~ /PORT-W-LOCKPORTACTIVE: A packet with source MAC ([0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}) tried to access through port e(\d+) which is locked/i
    #    )
    #{
    #    $trapHashRef->{'trapType'}    = 'secureMacAddrViolation';
    #    $trapHashRef->{'trapMac'}     = lc($1);
    #    $trapHashRef->{'trapIfIndex'} = $2;
    #    $trapHashRef->{'trapVlan'}
    #        = $this->getVlan( $trapHashRef->{'trapIfIndex'} );
    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

sub isDefinedVlan {
    my ( $this, $vlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->trace("isDefinedVlan vlan: $vlan ?");
    if ( $vlan == 1 ) {
        return 1;
    }
    return $this->SUPER::isDefinedVlan($vlan);
}

sub getTrunkPorts {
    my ($this) = @_;
    my $OID_vlanPortModeState = '1.3.6.1.4.1.89.48.22.1.1';    #RADLAN-vlan-MIB
    my @trunkPorts;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectRead() ) {
        return -1;
    }
    $logger->trace(
        "SNMP get_table for vlanPortModeState: $OID_vlanPortModeState");
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => $OID_vlanPortModeState );
    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            if ( $result->{$key} == 3 ) {
                $key =~ /^$OID_vlanPortModeState\.(\d+)$/;
                push @trunkPorts, $1;
                $logger->debug(
                    "Switch " . $this->{_ip} . " trunk port: $1" );
            }
        }
    } else {
        $logger->error( "Problem while reading vlanPortModeState for switch "
                . $this->{_ip} );
        return -1;
    }
    return @trunkPorts;
}

sub getUpLinks {
    my ($this) = @_;
    my @upLinks;

    if ( lc(@{ $this->{_uplink} }[0]) eq 'dynamic' ) {
        @upLinks = $this->getTrunkPorts();
    } else {
        @upLinks = @{ $this->{_uplink} };
    }
    return @upLinks;
}

sub _setVlan {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_dot1qVlanStaticUntaggedPorts
        = '1.3.6.1.2.1.17.7.1.4.3.1.4';    # Q-BRIDGE-MIB
    my $OID_dot1qVlanStaticEgressPorts
        = '1.3.6.1.2.1.17.7.1.4.3.1.2';    # Q-BRIDGE-MIB
    my $result;

    $logger->trace( "locking - trying to lock \$switch_locker{"
            . $this->{_ip}
            . "} in _setVlan" );
    {
        lock %{ $switch_locker_ref->{ $this->{_ip} } };
        $logger->trace( "locking - \$switch_locker{"
                . $this->{_ip}
                . "} locked in _setVlan" );

        # get current egress and untagged ports
        $this->{_sessionRead}->translate(0);
        $logger->trace(
            "SNMP get_request for dot1qVlanStaticUntaggedPorts and dot1qVlanStaticEgressPorts"
        );
        if ( $oldVlan != 1 ) {
            if ( $newVlan != 1 ) {
                $result = $this->{_sessionRead}->get_request(
                    -varbindlist => [
                        "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
                        "$OID_dot1qVlanStaticEgressPorts.$newVlan",
                        "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan",
                        "$OID_dot1qVlanStaticUntaggedPorts.$newVlan"
                    ]
                );

                # calculate new settings
                my $egressPortsOldVlan
                    = $this->modifyBitmask(
                    $result->{"$OID_dot1qVlanStaticEgressPorts.$oldVlan"},
                    $ifIndex - 1, 0 );
                my $egressPortsVlan
                    = $this->modifyBitmask(
                    $result->{"$OID_dot1qVlanStaticEgressPorts.$newVlan"},
                    $ifIndex - 1, 1 );
                my $untaggedPortsOldVlan
                    = $this->modifyBitmask(
                    $result->{"$OID_dot1qVlanStaticUntaggedPorts.$oldVlan"},
                    $ifIndex - 1, 0 );
                my $untaggedPortsVlan
                    = $this->modifyBitmask(
                    $result->{"$OID_dot1qVlanStaticUntaggedPorts.$newVlan"},
                    $ifIndex - 1, 1 );
                $this->{_sessionRead}->translate(1);

                # set all values
                if ( !$this->connectWrite() ) {
                    return 0;
                }
                $logger->trace(
                    "SNMP set_request for egressPorts, untaggedPorts and Pvid for new VLAN"
                );
                $result = $this->{_sessionWrite}->set_request(
                    -varbindlist => [
                        "$OID_dot1qVlanStaticEgressPorts.$newVlan",
                        Net::SNMP::OCTET_STRING,
                        $egressPortsVlan,
                        "$OID_dot1qVlanStaticUntaggedPorts.$newVlan",
                        Net::SNMP::OCTET_STRING,
                        $untaggedPortsVlan,
                        "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan",
                        Net::SNMP::OCTET_STRING,
                        $untaggedPortsOldVlan,
                        "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
                        Net::SNMP::OCTET_STRING,
                        $egressPortsOldVlan
                    ]
                );
            } else {
                $result = $this->{_sessionRead}->get_request(
                    -varbindlist => [
                        "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
                        "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan",
                    ]
                );

                # calculate new settings
                my $egressPortsOldVlan
                    = $this->modifyBitmask(
                    $result->{"$OID_dot1qVlanStaticEgressPorts.$oldVlan"},
                    $ifIndex - 1, 0 );
                my $untaggedPortsOldVlan
                    = $this->modifyBitmask(
                    $result->{"$OID_dot1qVlanStaticUntaggedPorts.$oldVlan"},
                    $ifIndex - 1, 0 );
                $this->{_sessionRead}->translate(1);

                # set all values
                if ( !$this->connectWrite() ) {
                    return 0;
                }
                $logger->trace(
                    "SNMP set_request for egressPorts, untaggedPorts and Pvid for new VLAN"
                );
                $result = $this->{_sessionWrite}->set_request(
                    -varbindlist => [
                        "$OID_dot1qVlanStaticUntaggedPorts.$oldVlan",
                        Net::SNMP::OCTET_STRING,
                        $untaggedPortsOldVlan,
                        "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
                        Net::SNMP::OCTET_STRING,
                        $egressPortsOldVlan
                    ]
                );
            }
        } else {
            $result = $this->{_sessionRead}->get_request(
                -varbindlist => [
                    "$OID_dot1qVlanStaticEgressPorts.$newVlan",
                    "$OID_dot1qVlanStaticUntaggedPorts.$newVlan",
                ]
            );

            # calculate new settings
            my $egressPortsVlan
                = $this->modifyBitmask(
                $result->{"$OID_dot1qVlanStaticEgressPorts.$newVlan"},
                $ifIndex - 1, 1 );
            my $untaggedPortsVlan
                = $this->modifyBitmask(
                $result->{"$OID_dot1qVlanStaticUntaggedPorts.$newVlan"},
                $ifIndex - 1, 1 );
            $this->{_sessionRead}->translate(1);

            # set all values
            if ( !$this->connectWrite() ) {
                return 0;
            }

            $logger->trace(
                "SNMP set_request for egressPorts, untaggedPorts and Pvid for new VLAN"
            );
            $result = $this->{_sessionWrite}->set_request(
                -varbindlist => [
                    "$OID_dot1qVlanStaticEgressPorts.$newVlan",
                    Net::SNMP::OCTET_STRING,
                    $egressPortsVlan,
                    "$OID_dot1qVlanStaticUntaggedPorts.$newVlan",
                    Net::SNMP::OCTET_STRING,
                    $untaggedPortsVlan,
                ]
            );
        }
        if ( !defined($result) ) {
            $logger->error(
                "error setting egressPorts, untaggedPorts for old VLAN: "
                    . $this->{_sessionWrite}->error );
        }
    }
    $logger->trace( "locking - \$switch_locker{"
            . $this->{_ip}
            . "} unlocked in _setVlan" );
    return ( defined($result) );
}

# Disabling port-security related code
# --
# Warning:
# if you uncomment this sub, you need to fix it, the way it uses Net::Telnet is buggy. 
# The connection should be made from inside the eval block. 
# See other telnet consuming switches for correct implementation.
#sub connectTelnet {
#    my ($this)       = @_;
#    my $logger       = Log::Log4perl::get_logger( ref($this) );
#    my $maxTries     = 50;
#    my $tryNb        = 1;
#    my $cliAvailable = 0;
#
#    $logger->trace("About to try connecting to switch using telnet");
#    my $t; = new Net::Telnet( Prompt => '/console# $/' );
#    while ( ( $tryNb <= $maxTries ) && ( !$cliAvailable ) ) {
#        eval {
#            $t->open( $this->{_ip} );
#            $t->waitfor(
#                '/Execute\\033\[21;18H\\033\[7mEdit\\033\[0m\\033\[21;18H/');
#            $t->put("\n");
#            $t->waitfor('/Execute/');
#            $t->put( $this->{_cliUser} . "\n" );
#            $t->waitfor('/Execute/');
#            $t->put( $this->{_cliPwd} . "\n" );
#            $t->waitfor('/Execute/');
#            $t->put("\033");
#            $t->waitfor('/Execute/');
#            $t->put("\033[C");
#            $t->waitfor('/Execute/');
#            $t->put("\n");
#            $t->waitfor('/Operation complete/');
#            $t->put(" ");
#            $t->waitfor('/Menu/');
#            $t->put("\032");
#            $t->waitfor('/>/');
#            $t->put("lcli\n");
#            $t->waitfor('/User Name:/');
#            $t->put( $this->{_cliUser} . "\n" );
#            $t->waitfor('/Password:/');
#            $t->put( $this->{_cliPwd} . "\n" );
#            $t->waitfor('/console/');
#        };
#        if ( !$@ ) {
#            $cliAvailable = 1;
#            $logger->debug("cli is available in attempt nb $tryNb");
#        } else {
#            $logger->debug("unable to connect in atempt nb $tryNb: $@");
#            sleep(1);
#            $tryNb++;
#        }
#    }
#    if ($cliAvailable) {
#        return $t;
#    } else {
#        $logger->error("unable to establish telnet connection");
#        return 0;
#    }
#}

# disabling port-security since its known not to work
#sub isPortSecurityEnabled {
#    my ( $this, $ifIndex ) = @_;
#    my $logger = Log::Log4perl::get_logger( ref($this) );
#    my $OID_swIfHostMode
#        = '1.3.6.1.4.1.89.43.1.1.30';    #RADLAN-rlInterfaces MIB
#
#    if ( !$this->connectRead() ) {
#        return 0;
#    }
#
#    #determine if port security is enabled
#    $logger->trace(
#        "SNMP get_request for swIfHostMode: $OID_swIfHostMode.$ifIndex");
#    my $result = $this->{_sessionRead}
#        ->get_request( -varbindlist => [ "$OID_swIfHostMode.$ifIndex" ] );
#    return (   exists( $result->{"$OID_swIfHostMode.$ifIndex"} )
#            && ( $result->{"$OID_swIfHostMode.$ifIndex"} ne 'noSuchInstance' )
#            && ( $result->{"$OID_swIfHostMode.$ifIndex"} == 2 ) );
#}

# disabling port-security since its known not to work
#sub setPortSecurityDisabled {
#    my ( $this, $ifIndex ) = @_;
#    my $logger = Log::Log4perl::get_logger( ref($this) );
#
#    $logger->info("function not implemented yet !");
#    return 1;
#}

# disabling port-security since its known not to work
#sub isDynamicPortSecurityEnabled {
#    my ( $this, $ifIndex ) = @_;
#    my $logger = Log::Log4perl::get_logger( ref($this) );
#    return ( $this->isPortSecurityEnabled($ifIndex)
#            && ( !$this->isStaticPortSecurityEnabled($ifIndex) ) );
#}

# disabling port-security since its known not to work
#sub isStaticPortSecurityEnabled {
#    my ( $this, $ifIndex ) = @_;
#    my $logger                  = Log::Log4perl::get_logger( ref($this) );
#    my $OID_swIfLockAdminStatus = '1.3.6.1.4.1.89.43.1.1.8';
#
#    if ( !$this->connectRead() ) {
#        return -1;
#    }
#
#    #determine if port security is enabled
#    if ( !$this->isPortSecurityEnabled($ifIndex) ) {
#        $logger->debug("port security is not enabled");
#        return 0;
#    }
#
#    #determine swIfLockAdminStatus
#    $logger->trace(
#        "SNMP get_request for swIfLockAdminStatus: $OID_swIfLockAdminStatus.$ifIndex"
#    );
#    my $result = $this->{_sessionRead}->get_request(
#        -varbindlist => [ "$OID_swIfLockAdminStatus.$ifIndex" ] );
#    if (( !exists( $result->{"$OID_swIfLockAdminStatus.$ifIndex"} ) )
#        || ( $result->{"$OID_swIfLockAdminStatus.$ifIndex"} eq
#            'noSuchInstance' )
#        )
#    {
#        $logger->error("ERROR: could not obtain swIfLockAdminStatus");
#        return 0;
#    }
#    return ( $result->{"$OID_swIfLockAdminStatus.$ifIndex"} == 1 );
#}

sub getMaxMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger                      = Log::Log4perl::get_logger( ref($this) );
    my $OID_swIfLockMaxMacAddresses = '1.3.6.1.4.1.89.43.1.1.38';

    if ( !$this->connectRead() ) {
        return -1;
    }

    #determine if port security is enabled
    if ( !$this->isPortSecurityEnabled($ifIndex) ) {
        $logger->debug("port security is not enabled");
        return -1;
    }

    #determine max number of MAC addresses allowed
    $logger->trace(
        "SNMP get_request for swIfLockMaxMacAddresses: $OID_swIfLockMaxMacAddresses.$ifIndex"
    );
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => [ "$OID_swIfLockMaxMacAddresses.$ifIndex" ] );
    if (( !exists( $result->{"$OID_swIfLockMaxMacAddresses.$ifIndex"} ) )
        || ( $result->{"$OID_swIfLockMaxMacAddresses.$ifIndex"} eq
            'noSuchInstance' )
        )
    {
        $logger->error("ERROR: could not obtain swIfLockMaxMacAddresses");
        return -1;
    }
    return $result->{"$OID_swIfLockMaxMacAddresses.$ifIndex"};
}

# disabling port-security since its known not to work
#sub getSecureMacAddresses {
#    my ( $this, $ifIndex ) = @_;
#    my $logger               = Log::Log4perl::get_logger( ref($this) );
#    my $secureMacAddrHashRef = {};
#    my $ifName               = $this->getIfName($ifIndex);
#    if ( $ifName eq '' ) {
#        return $secureMacAddrHashRef;
#    }
#    my $telnetConnection = $this->connectTelnet();
#    if ( !$telnetConnection ) {
#        return $secureMacAddrHashRef;
#    }
#
#    $logger->trace("telnet cmd: show bridge address-table static ethernet $ifName");
#    my @lines = $telnetConnection->cmd(
#        "show bridge address-table static ethernet $ifName");
#    foreach my $line (@lines) {
#        if ( $line
#            =~ /(\d+)\s+([0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}).+secure/
#            )
#        {
#            my $vlan = $1;
#            my $mac  = $2;
#            push @{ $secureMacAddrHashRef->{$mac} }, $vlan;
#        }
#    }
#    $telnetConnection->close();
#    return $secureMacAddrHashRef;
#}

# disabling port-security since its known not to work
#sub getAllSecureMacAddresses {
#    my ($this)               = @_;
#    my $logger               = Log::Log4perl::get_logger( ref($this) );
#    my $secureMacAddrHashRef = {};
#    my %ifNameIfIndexHash    = $this->getIfNameIfIndexHash();
#    my $telnetConnection     = $this->connectTelnet();
#    if ( !$telnetConnection ) {
#        return $secureMacAddrHashRef;
#    }
#
#    my @lines = $telnetConnection->cmd("show bridge address-table static");
#    foreach my $line (@lines) {
#        if ( $line
#            =~ /(\d+)\s+([0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2})\s+([eg]\d+)\s+secure/
#            )
#        {
#            my $vlan    = $1;
#            my $mac     = $2;
#            my $ifName  = $3;
#            my $ifIndex = $ifNameIfIndexHash{$ifName};
#            push @{ $secureMacAddrHashRef->{$mac}->{$ifIndex} }, $vlan;
#        }
#    }
#    $telnetConnection->close();
#    return $secureMacAddrHashRef;
#}

# disabling port-security since its known not to work
#sub authorizeMAC {
#    my ( $this, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
#    my $logger = Log::Log4perl::get_logger( ref($this) );
#    my $oid_cpsSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.2.1.4';
#
#    if ( !$this->isProductionMode() ) {
#        $logger->info(
#            "not in production mode ... we won't add an entry to the SecureMacAddrTable"
#        );
#        return 1;
#    }
#
#    my $ifName = $this->getIfName($ifIndex);
#    if ( $ifName eq '' ) {
#        $logger->warn("unable to get ifName from ifIndex");
#        return 0;
#    }
#
#    my $telnetConnection = $this->connectTelnet();
#    if ( !$telnetConnection ) {
#        $logger->warn("unable to get telnet connection");
#        return 0;
#    }
#
#    if ( ($deauthMac) && ($deauthVlan) ) {
#        $logger->trace("telnet interactive cmd: configure interface vlan $deauthVlan no bridge address $deauthMac");
#        $telnetConnection->put("configure\n");
#        $telnetConnection->waitfor('/console\(config\)#/');
#        $telnetConnection->put("interface vlan $deauthVlan\n");
#        $telnetConnection->waitfor('/console\(config-if\)#/');
#        $telnetConnection->put("no bridge address $deauthMac\n");
#        $telnetConnection->waitfor('/console\(config-if\)#/');
#        $telnetConnection->put("end\n");
#        $telnetConnection->waitfor('/console#/');
#        $logger->trace("successful");
#    }
#    if ( ($authMac) && ($authVlan) ) {
#        $logger->trace("telnet interactive cmd: configure interface vlan $authVlan bridge address $authMac ethernet $ifName secure");
#        $telnetConnection->put("configure\n");
#        $telnetConnection->waitfor('/console\(config\)#/');
#        $telnetConnection->put("interface vlan $authVlan\n");
#        $telnetConnection->waitfor('/console\(config-if\)#/');
#        $telnetConnection->put(
#            "bridge address $authMac ethernet $ifName secure\n");
#        $telnetConnection->waitfor('/console\(config-if\)#/');
#        $telnetConnection->put("end\n");
#        $telnetConnection->waitfor('/console#/');
#        $logger->trace("successful");
#    }
#    $telnetConnection->close();
#    return 1;
#}

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
