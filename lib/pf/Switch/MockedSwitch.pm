package pf::Switch::MockedSwitch;

=head1 NAME

pf::Switch::MockedSwitch - Fake switch module designed to document our interfaces and for tests

=head1 SYNOPSIS

As it was implemented it became obvious that it would be useful to help us understand our own switch interfaces too.

This modules extends pf::Switch.

=head1 STATUS

It's not complete yet

=head1 TODO

* all methods here should have at least one logger->debug statement and a realistic sleep based on what it does

* Full POD for pf::Switch

* Add new subs from Cisco and friends that were added in trunk

* Create a pf::MockedWireless

=head1 BUGS AND LIMITATIONS

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Net::SNMP;
use Test::MockObject::Extends;
use Time::HiRes qw( usleep );

use base ('pf::Switch');

use pf::constants qw($TRUE $FALSE);
use pf::constants::role qw($MAC_DETECTION_ROLE);
use pf::config qw(
    %Config
    $MAC
    $PORT
    $SSID
);
# importing switch constants
use pf::Switch::constants;
use pf::util;
use pf::config::util;

# these are in microseconds (not milliseconds!) because of Time::HiRes's usleep
# TODO benchmark more sensible values
use constant CONNECT_READ_DELAY => 100_000;
use constant CONNECT_V3_READ_DELAY => 200_000;
use constant CONNECT_WRITE_DELAY => 100_000;
use constant CONNECT_V3_WRITE_DELAY => 200_000;

use constant DISCONNECT_DELAY => 10_000;

use constant READ_GET_DELAY => 50_000;
use constant READ_TABLE_DELAY => 250_000;
use constant WRITE_SET_DELAY => 50_000;

use constant MYSQL_CONNECTION_DELAY => 500_000;

use constant TELNET_CONNECTION_DELAY => 1_000_000;
use constant TELNET_SMALL_EXCHANGE => 100_000;
use constant TELNET_LARGE_EXCHANGE => 1_000_000;

# switch configuration
Readonly::Scalar our $REMOVED_TRAPS_ENABLED => 0;
Readonly::Scalar our $IS_TRUNK_PORTS => 0;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
sub supportsRadiusDynamicVlanAssignment { return $TRUE; }
sub supportsExternalPortal { return $TRUE; }
sub supportsMABFloatingDevices { return $TRUE; }
sub supportsWebFormRegistration { return $TRUE }
sub supportsAccessListBasedEnforcement { return $TRUE }
# VoIP technology supported
sub supportsRadiusVoip { return $TRUE; }
# special features supported
sub supportsFloatingDevice { return $TRUE; }
sub supportsSaveConfig { return $FALSE; }
sub supportsCdp { return $TRUE; }
sub supportsLldp { return $FALSE; }
sub supportsRoamingAccounting { return $FALSE }
# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT,$SSID); }

# first, we are re-implementing all of pf::Switch that has effects on switches to make sure it doesn't do anything

=item connectRead - establish read connection to switch

=cut

sub connectRead {
    my $self   = shift;
    my $logger = $self->logger;
    if ( defined( $self->{_sessionRead} ) ) {
        return 1;
    }

    $logger->debug("opening fake SNMP v" . $self->{_SNMPVersion} . " read connection to $self->{_id}");
    if ( $self->{_SNMPVersion} eq '3' ) {

        usleep(CONNECT_V3_READ_DELAY);
       # $self->{_sessionRead} = 1;

    } else {

        usleep(CONNECT_READ_DELAY);
       # $self->{_sessionRead} = 1;
    }

    $self->{_sessionRead} = new Net::SNMP;

    # TODO extract mocking in mockReadObject() method
    # Make the object mockable
    $self->{_sessionRead} = Test::MockObject::Extends->new($self->{_sessionRead});

    # TODO extract sub in coderef
    $self->{_sessionRead}
        ->mock('get_request',
            sub {
                my ($self, %args) = @_;
                my $request_type = 'get_request';
                $logger->trace("Mocked $request_type got args: ".Dumper(\%args));

                usleep(READ_GET_DELAY);
                if (defined($args{'-varbindlist'}) && @{$args{'-varbindlist'}} == 1) {
                    # TODO extract in a dispatch_read_)oid() method
                    # fetches the first oid argument
                    my $request_oid = ${$args{'-varbindlist'}}[0];

                    if ($request_oid =~ /^1.3.6.1.2.1.2.2.1.8/) {
                        $logger->trace("$request_type: we always return up $SNMP::UP for this OID");
                        return { $request_oid => $SNMP::UP };

                    } elsif ($request_oid =~ /^1.3.6.1.2.1.31.1.1.1.18/) {
                        $logger->trace("$request_type: returning a fake port description");
                        return { $request_oid => 'fake port description' };
                    } else {
                        $logger->trace("$request_type: returning $TRUE by default");
                        return { $request_oid => $TRUE };
                    }
                } else {
                    $logger->debug("$request_type: returning $TRUE for lack of a better idea what to do");
                }
                return $TRUE;
            }
        )->mock('get_table',
            sub {
                my ($self, %args) = @_;
                my $request_type = 'get_table';
                $logger->trace("Mocked $request_type got args: ".Dumper(\%args));

                usleep(READ_TABLE_DELAY);
                if (defined($args{'-baseoid'})) {
                    # TODO extract in a dispatch_read_)oid() method
                    my $request_oid = $args{'-baseoid'};

                    # TODO extract OIDs, return values into constants
                    if ($request_oid =~ /^1.3.6.1.2.1.17.1.4.1.2$/) {
                        $logger->trace("$request_type: returning a classic 2960 dot1d to ifIndex mapping");
                        # TODO extract into helper method?
                        my $result;
                        for (my $i = 1; $i <= 48; $i++) {
                            $result->{$request_oid.".".$i} = sprintf("100%02d",$i);
                        }
                        return $result;
                    } else {
                        $logger->trace("$request_type: returning $TRUE by default");
                        return { $request_oid => $TRUE };
                    }
                } else {
                    $logger->debug("$request_type: returning $TRUE for lack of a better idea what to do");
                }
                return $TRUE;
            }
        );

    $logger->debug("fetching sysLocation to make sure SNMP reads do work");
    usleep(READ_GET_DELAY);
    return 1;
}

=item disconnectRead - closing read connection to switch

=cut

sub disconnectRead {
    my $self   = shift;
    my $logger = $self->logger;
    if ( !defined( $self->{_sessionRead} ) ) {
        return 1;
    }

    $logger->debug( "closing fake SNMP v" . $self->{_SNMPVersion} . " read connection to $self->{_id}" );
    usleep(DISCONNECT_DELAY);
    delete ($self->{_sessionRead});
    return 1;
}

=item connectWriteTo

Establishes an SNMP Write connection to a given IP and installs the session object into this object's sessionKey.
It performs a write test to make sure that the write actually works.

=cut

sub connectWriteTo {
    my ($self, $ip, $sessionKey) = @_;
    my $logger = $self->logger;

    # if connection already exists, no need to connect again
    return 1 if ( defined( $self->{$sessionKey} ) );

    $logger->debug( "opening fake SNMP v" . $self->{_SNMPVersion} . " write connection to $ip" );
    if ( $self->{_SNMPVersion} eq '3' ) {

        usleep(CONNECT_V3_WRITE_DELAY);
    } else {

        usleep(CONNECT_WRITE_DELAY);
    }

    # TODO extract mocking in mockWriteObject() method
    # Make the object mockable
    $self->{$sessionKey} = Test::MockObject::Extends->new($self->{$sessionKey});

    # TODO extract sub in coderef
    $self->{$sessionKey}->mock(
        'set_request',
        sub {
            my ($self, %args) = @_;
            my $request_type = 'set_request';
            $logger->trace("Mocked $request_type got args: ".Dumper(\%args));

            usleep(WRITE_SET_DELAY);

            # SNMP SET arguments comes in pair of 3
            my $legal_args = (defined($args{'-varbindlist'}) && @{$args{'-varbindlist'}} % 3 == 0);
            if ($legal_args) {
                # TODO extract in a dispatch_write_oid() method
                # fetches the first oid argument
                my $request_oid = ${$args{'-varbindlist'}}[0];

                $logger->trace("$request_type: returning $TRUE by default");
                return { $request_oid => $TRUE };
            } else {
                $logger->debug("$request_type: returning $TRUE for lack of a better idea what to do");
            }
            return $TRUE;
        }
    );

    # fetching sysLocation (we will set it so we need to get it to set the same)
    usleep(READ_GET_DELAY);

    $logger->debug( "SNMP fake set request tests if we can really write" );
    usleep(WRITE_SET_DELAY);

    return 1;
}

=item disconnectWriteTo

Closes an SNMP Write connection. Requires sessionKey stored in object (as when calling connectWriteTo).

=cut

sub disconnectWriteTo {
    my ($self, $sessionKey) = @_;
    my $logger = $self->logger;

    return 1 if ( !defined( $self->{$sessionKey} ) );

    $logger->debug( "closing fake SNMP v" . $self->{_SNMPVersion} . " write connection" );
    usleep(DISCONNECT_DELAY);
    $self->{$sessionKey} = undef;
    return 1;
}

=item _setVlanByOnlyModifyingPvid

=cut

sub _setVlanByOnlyModifyingPvid {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';    # Q-BRIDGE-MIB
    my $result;

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $dot1dBasePort = $self->getDot1dBasePortForThisIfIndex($ifIndex);

    $logger->debug("SNMP fake set_request for Pvid for new VLAN");
    $result
        = $self->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_dot1qPvid.$dot1dBasePort", Net::SNMP::GAUGE32, $newVlan ]
        );
    if ( !defined($result) ) {
        $logger->error(
            "error setting Pvid: " . $self->{_sessionWrite}->error );
    }
    return ( defined($result) );
}

=item getIfOperStatus - obtain the ifOperStatus of the specified switch port

=cut

sub getIfOperStatus {
    my ( $self, $ifIndex ) = @_;
    my $logger           = $self->logger;
    my $oid_ifOperStatus = '1.3.6.1.2.1.2.2.1.8';
    if ( !$self->connectRead() ) {
        return 0;
    }

    $logger->debug("SNMP fake get_request for ifOperStatus: $oid_ifOperStatus.$ifIndex");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$oid_ifOperStatus.$ifIndex"] );

    return $result->{"$oid_ifOperStatus.$ifIndex"};
}

=item getAlias - get the port description

=cut

sub getAlias {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }

    my $OID_ifAlias = '1.3.6.1.2.1.31.1.1.1.18';
    $logger->debug("SNMP fake get_request for ifAlias: $OID_ifAlias.$ifIndex");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_ifAlias.$ifIndex"] );
    return $result->{"$OID_ifAlias.$ifIndex"};
}

=item getSwitchLocation - get the switch location string

=cut

sub getSwitchLocation {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }
    my $OID_sysLocation = '1.3.6.1.2.1.1.6.0';
    $logger->debug("SNMP fake get_request for sysLocation: $OID_sysLocation");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_sysLocation"] );
    return $result->{"$OID_sysLocation"};
}

=item setAlias - set the port description

=cut

sub setAlias {
    my ( $self, $ifIndex, $alias ) = @_;
    my $logger = $self->logger;
    $logger->info( "setting "
            . $self->{_id}
            . " ifIndex $ifIndex ifAlias from "
            . $self->getAlias($ifIndex)
            . " to $alias" );
    if ( !$self->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't change this port ifAlias");
        return 1;
    }
    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $OID_ifAlias = '1.3.6.1.2.1.31.1.1.1.18';
    $logger->debug("SNMP fake set_request for ifAlias: $OID_ifAlias.$ifIndex = $alias");
    my $result = $self->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_ifAlias.$ifIndex", Net::SNMP::OCTET_STRING, $alias ] );
    return ( defined($result) );
}

=item getSysName - return the administratively-assigned name of the switch. By convention, this is the switch's
fully-qualified domain name

=cut

sub getSysName {
    my ($self) = @_;
    my $logger = $self->logger;
    my $OID_sysName = '1.3.6.1.2.1.1.5';                     # mib-2
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->debug("SNMP fake get_request for sysName: $OID_sysName");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$OID_sysName] );
    if ( exists( $result->{$OID_sysName} )
        && ( $result->{$OID_sysName} ne 'noSuchInstance' ) )
    {
        return $result->{$OID_sysName};
    }
    return '';
}

=item getIfDesc - return ifDesc given ifIndex

=cut

sub getIfDesc {
    my ( $self, $ifIndex ) = @_;
    my $logger     = $self->logger;
    my $OID_ifDesc = '1.3.6.1.2.1.2.2.1.2';                     # IF-MIB
    my $oid        = $OID_ifDesc . "." . $ifIndex;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->debug("SNMP fake get_request for ifDesc: $oid");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid] );
    if ( exists( $result->{$oid} )
        && ( $result->{$oid} ne 'noSuchInstance' ) )
    {
        return $result->{$oid};
    }
    return '';
}

=item getIfName - return ifName given ifIndex

=cut

sub getIfName {
    my ( $self, $ifIndex ) = @_;
    my $logger     = $self->logger;
    my $OID_ifName = '1.3.6.1.2.1.31.1.1.1.1';                  # IF-MIB
    my $oid        = $OID_ifName . "." . $ifIndex;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->debug("SNMP fake get_request for ifName: $oid");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid] );
    if ( exists( $result->{$oid} )
        && ( $result->{$oid} ne 'noSuchInstance' ) )
    {
        return $result->{$oid};
    }
    return '';
}

=item getIfNameIfIndexHash - return ifName =E<gt> ifIndex hash

=cut

# FIXME this one doesn't work
sub getIfNameIfIndexHash {
    my ($self)     = @_;
    my $logger     = $self->logger;
    my $OID_ifName = '1.3.6.1.2.1.31.1.1.1.1';                  # IF-MIB
    my %ifNameIfIndexHash;
    if ( !$self->connectRead() ) {
        return %ifNameIfIndexHash;
    }
    $logger->debug("BROKEN SNMP fake get_request for ifName: $OID_ifName");
    my $result = $self->{_sessionRead}->get_table( -baseoid => $OID_ifName );
    foreach my $key ( keys %{$result} ) {
        $key =~ /^$OID_ifName\.(\d+)$/;
        $ifNameIfIndexHash{ $result->{$key} } = $1;
    }
    return %ifNameIfIndexHash;
}

=item setAdminStatus - shutdown or enable port

=cut

sub setAdminStatus {
    my ( $self, $ifIndex, $status ) = @_;
    my $logger            = $self->logger;
    my $OID_ifAdminStatus = '1.3.6.1.2.1.2.2.1.7';

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port ifAdminStatus");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }
    $logger->debug( "SNMP fake set_request for ifAdminStatus: $OID_ifAdminStatus.$ifIndex = $status" );
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_ifAdminStatus.$ifIndex", Net::SNMP::INTEGER, $status ]
    );
    return ( defined($result) );
}

=item bouncePort

Performs a shut / no-shut on the port.
Usually used to force the operating system to do a new DHCP Request after a VLAN change.

Just performing the wait, no setAdminStatus

=cut

sub bouncePort {
    my ($self, $ifIndex) = @_;

    #$self->setAdminStatus( $ifIndex, $SNMP::DOWN );
    sleep($Config{'snmp_traps'}{'bounce_duration'});
    #$self->setAdminStatus( $ifIndex, $SNMP::UP );

    return $TRUE;
}

=item getIfType - return the ifType

=cut

sub getIfType {
    my ( $self, $ifIndex ) = @_;
    my $logger     = $self->logger;
    my $OID_ifType = '1.3.6.1.2.1.2.2.1.3';                     #IF-MIB
    if ( !$self->connectRead() ) {
        return 0;
    }
    $logger->debug("SNMP fake get_request for ifType: $OID_ifType.$ifIndex");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_ifType.$ifIndex"] );
    #return $result->{"$OID_ifType.$ifIndex"};
    $logger->debug("returning ethernetCsmacd(6) which is what PacketFence expects");
    return $SNMP::ETHERNET_CSMACD;
}

sub getAllDot1dBasePorts {
    my ( $self, @ifIndexes ) = @_;
    my $logger = $self->logger;
    if ( !@ifIndexes ) {
        @ifIndexes = $self->getManagedIfIndexes();
    }
    my $dot1dBasePortHashRef;
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB
    if ( !$self->connectRead() ) {
        return $dot1dBasePortHashRef;
    }
    $logger->debug(
        "SNMP fake get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex");
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => $OID_dot1dBasePortIfIndex );
    my $dot1dBasePort = undef;
    foreach my $key ( keys %{$result} ) {
        my $ifIndex = $result->{$key};
        if ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) {
            $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
            $dot1dBasePort = $1;
            $logger->trace(
                "dot1dBasePort corresponding to ifIndex $ifIndex is $dot1dBasePort"
            );
            $dot1dBasePortHashRef->{$dot1dBasePort} = $ifIndex;
        }
    }
    return $dot1dBasePortHashRef;
}

=item getDot1dBasePortForThisIfIndex - returns the dot1dBasePort for a given ifIndex

=cut

sub getDot1dBasePortForThisIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB
    my $dot1dBasePort            = undef;
    if ( !$self->connectRead() ) {
        return $dot1dBasePort;
    }
    $logger->debug("SNMP fake get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex");
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => $OID_dot1dBasePortIfIndex );
    foreach my $key ( keys %{$result} ) {
        if ( $result->{$key} == $ifIndex ) {
            $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
            $dot1dBasePort = $1;
            $logger->debug(
                "dot1dBasePort corresponding to ifIndex $ifIndex is $dot1dBasePort"
            );
        }
    }
    return $dot1dBasePort;
}

# FIXME not properly mocked
sub getAllIfDesc {
    my ($self) = @_;
    my $logger = $self->logger;
    my $ifDescHashRef;
    my $OID_ifDesc = '1.3.6.1.2.1.2.2.1.2';    # IF-MIB

    if ( !$self->connectRead() ) {
        return $ifDescHashRef;
    }

    $logger->debug("BROKEN SNMP fake get_table for ifDesc: $OID_ifDesc");
    my $result = $self->{_sessionRead}->get_table( -baseoid => $OID_ifDesc );
    foreach my $key ( keys %{$result} ) {
        my $ifDesc = $result->{$key};
        $key =~ /^$OID_ifDesc\.(\d+)$/;
        my $ifIndex = $1;
        $ifDescHashRef->{$ifIndex} = $ifDesc;
    }
    return $ifDescHashRef;
}

# FIXME not properly mocked
sub getAllIfType {
    my ($self) = @_;
    my $logger = $self->logger;
    my $ifTypeHashRef;
    my $OID_ifType = '1.3.6.1.2.1.2.2.1.3';

    if ( !$self->connectRead() ) {
        return $ifTypeHashRef;
    }

    $logger->debug("BROKEN SNMP fake get_table for ifType: $OID_ifType");
    my $result = $self->{_sessionRead}->get_table( -baseoid => $OID_ifType );
    foreach my $key ( keys %{$result} ) {
        my $ifType = $result->{$key};
        $key =~ /^$OID_ifType\.(\d+)$/;
        my $ifIndex = $1;
        $ifTypeHashRef->{$ifIndex} = $ifType;
    }
    return $ifTypeHashRef;
}

# FIXME not properly mocked
sub getAllIfOctets {
    my ( $self, @ifIndexes ) = @_;
    my $logger          = $self->logger;
    my $oid_ifInOctets  = '1.3.6.1.2.1.2.2.1.10';
    my $oid_ifOutOctets = '1.3.6.1.2.1.2.2.1.16';
    my $ifOctetsHashRef;
    if ( !$self->connectRead() ) {
        return $ifOctetsHashRef;
    }
    if ( !@ifIndexes ) {
        @ifIndexes = $self->getManagedIfIndexes();
    }

    $logger->debug("BROKEN SNMP fake get_table for ifInOctets $oid_ifInOctets");
    my $result
        = $self->{_sessionRead}->get_table( -baseoid => $oid_ifInOctets );
    foreach my $key ( sort keys %$result ) {
        if ( $key =~ /^$oid_ifInOctets\.(\d+)$/ ) {
            my $ifIndex = $1;
            if ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) {
                $ifOctetsHashRef->{$ifIndex}->{'in'} = $result->{$key};
            }
        } else {
            $logger->warn("error key $key");
        }
    }
    $logger->debug("BROKEN SNMP fake get_table for ifOutOctets $oid_ifOutOctets");
    $result
        = $self->{_sessionRead}->get_table( -baseoid => $oid_ifOutOctets );
    foreach my $key ( sort keys %$result ) {
        if ( $key =~ /^$oid_ifOutOctets\.(\d+)$/ ) {
            my $ifIndex = $1;
            if ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) {
                $ifOctetsHashRef->{$ifIndex}->{'out'} = $result->{$key};
            }
        } else {
            $logger->warn("error key $key");
        }
    }
    return $ifOctetsHashRef;
}

# FIXME not properly mocked
sub isIfLinkUpDownTrapEnable {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_ifLinkUpDownTrapEnable = '1.3.6.1.2.1.31.1.1.1.14'; # from IF-MIB
    $logger->debug("SNMP fake get_request for ifLinkUpDownTrapEnable: $OID_ifLinkUpDownTrapEnable");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [ "$OID_ifLinkUpDownTrapEnable.$ifIndex" ] );
    return ( exists( $result->{"$OID_ifLinkUpDownTrapEnable.$ifIndex"} )
                && ( $result->{"$OID_ifLinkUpDownTrapEnable.$ifIndex"} ne 'noSuchInstance' )
                && ( $result->{"$OID_ifLinkUpDownTrapEnable.$ifIndex"} == 1 ) );
}

# FIXME not properly mocked
sub setIfLinkUpDownTrapEnable {
    my ( $self, $ifIndex, $enable ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port ifLinkUpDownTrapEnable");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $OID_ifLinkUpDownTrapEnable = '1.3.6.1.2.1.31.1.1.1.14'; # from IF-MIB
    my $truthValue = $enable ? $SNMP::TRUE : $SNMP::FALSE;

    $logger->debug("BROKEN SNMP fake set_request for ifLinkUpDownTrapEnable: $OID_ifLinkUpDownTrapEnable");
    my $result = $self->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_ifLinkUpDownTrapEnable.$ifIndex", Net::SNMP::INTEGER, $truthValue ] );
    return ( defined($result) );
}

# FIXME not properly mocked
sub getVersion {
    my ($self)       = @_;
    my $oid_sysDescr = '1.3.6.1.2.1.1.1.0';
    my $logger       = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }
    $logger->debug("SNMP fake get_request for sysDescr: $oid_sysDescr");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => [$oid_sysDescr] );
    my $sysDescr = ( $result->{$oid_sysDescr} || '' );
    if ( $sysDescr =~ m/V(\d{1}\.\d{2}\.\d{2})/ ) {
        return $1;
    } elsif ( $sysDescr =~ m/Version (\d+\.\d+\([^)]+\)[^,\s]*)(,|\s)+/ ) {
        return $1;
    } else {
        return $sysDescr;
    }
}

sub isNewerVersionThan {
    my ( $self, $versionToCompareToString ) = @_;
    my $currentVersion = $self->getVersion();
    my @detectedOSVersionArray;
    if ( $currentVersion =~ /^(\d+)\.(\d+)\(([0-9]+)[^0-9)]*\)(.+)$/ ) {
        @detectedOSVersionArray = ( $1, $2, $3, $4 );
        my @versionToCompareToArray;
        if ( $versionToCompareToString
            =~ /^(\d+)\.(\d+)\(([0-9]+)[^0-9)]*\)(.+)$/ )
        {
            @versionToCompareToArray = ( $1, $2, $3, $4 );
            if ( $detectedOSVersionArray[3] =~ /^([A-Za-z]+)(\d+)([a-z]?)$/ )
            {
                my $d1 = $1;
                my $d2 = $2;
                my $d3 = $3;
                if ( $versionToCompareToArray[3]
                    =~ /^([A-Za-z]+)(\d+)([a-z]?)$/ )
                {
                    my $c1 = $1;
                    my $c2 = $2;
                    my $c3 = $3;
                    if (!(     ( $d1 lt $c1 )
                            || ( ( $d1 eq $c1 ) && ( $d2 < $c2 ) )
                            || (   ( $d1 eq $c1 )
                                && ( $d2 == $c2 )
                                && ( $d3 lt $c3 ) )
                        )
                        )
                    {
                        $detectedOSVersionArray[3]  = 'b';
                        $versionToCompareToArray[3] = 'a';
                    } else {
                        $detectedOSVersionArray[3]  = 'a';
                        $versionToCompareToArray[3] = 'b';
                    }
                }
            }
            return !(
                ( $detectedOSVersionArray[0] < $versionToCompareToArray[0] )
                || ((   $detectedOSVersionArray[0]
                        == $versionToCompareToArray[0]
                    )
                    && ( $detectedOSVersionArray[1]
                        < $versionToCompareToArray[1] )
                )
                || ((   $detectedOSVersionArray[0]
                        == $versionToCompareToArray[0]
                    )
                    && ( $detectedOSVersionArray[1]
                        == $versionToCompareToArray[1] )
                    && ( $detectedOSVersionArray[2]
                        < $versionToCompareToArray[2] )
                )
                || ((   $detectedOSVersionArray[0]
                        == $versionToCompareToArray[0]
                    )
                    && ( $detectedOSVersionArray[1]
                        == $versionToCompareToArray[1] )
                    && ( $detectedOSVersionArray[2]
                        == $versionToCompareToArray[2] )
                    && ( $detectedOSVersionArray[3]
                        lt $versionToCompareToArray[3] )
                )
            );
        }
    }
    return 0;
}

# FIXME halfly mocked
sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;

    #link up/down
    if ( $trapString
        =~ /BEGIN VARIABLEBINDINGS [^|]+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.6\.3\.1\.1\.5\.([34])\|.1.3.6.1.2.1.2.2.1.1.([0-9]+)/
        )
    {
        $trapHashRef->{'trapType'} = ( ( $1 == 3 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;

    } elsif ( $trapString
        =~ /^BEGIN TYPE ([23]) END TYPE BEGIN SUBTYPE 0 END SUBTYPE BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.(\d+) = INTEGER: /
        )
    {
        $trapHashRef->{'trapType'} = ( ( $1 == 2 ) ? "down" : "up" );
        $trapHashRef->{'trapIfIndex'} = $2;
        # CISCO-MAC-NOTIFICATION-MIB cmnHistMacChangedMsg
    } elsif (
        ( $trapString
            =~ /BEGIN VARIABLEBINDINGS [^|]+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.4\.1\.9\.9\.215\.2\.0\.1\|\.1\.3\.6\.1\.4\.1\.9\.9\.215\.1\.1\.8\.1\.2\.[0-9]+ = Hex-STRING: ([0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2})/
        ) || ( $trapString
            =~ /BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.4\.1\.9\.9\.215\.1\.1\.8\.1\.2\.[0-9]+ = Hex-STRING: ([0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2}) ([0-9A-Z]{2} [0-9A-Z]{2})/
        ) )
    {
        $trapHashRef->{'trapType'} = 'mac';
        if ( $1 == 1 ) {
            $trapHashRef->{'trapOperation'} = 'learnt';
        } elsif ( $1 == 2 ) {
            $trapHashRef->{'trapOperation'} = 'removed';
        } else {
            $trapHashRef->{'trapOperation'} = 'unknown';
        }
        $trapHashRef->{'trapVlan'}    = $2;
        $trapHashRef->{'trapMac'}     = lc($3);
        $trapHashRef->{'trapIfIndex'} = $4;
        $trapHashRef->{'trapVlan'} =~ s/ //g;
        $trapHashRef->{'trapVlan'} = hex( $trapHashRef->{'trapVlan'} );
        $trapHashRef->{'trapIfIndex'} =~ s/ //g;
        $trapHashRef->{'trapIfIndex'} = hex( $trapHashRef->{'trapIfIndex'} );
        $trapHashRef->{'trapMac'} =~ s/ /:/g;

        #convert the dot1dBasePort into an ifIndex
        my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';   #BRIDGE-MIB
        my $dot1dBasePort = $trapHashRef->{'trapIfIndex'};

        #populate list of Vlans we must potentially connect to to
        #convert the dot1dBasePort into an ifIndex
        my @vlansToTest = ();
        my $macDetectionVlan = $self->getVlanByName($MAC_DETECTION_ROLE);
        push @vlansToTest, $trapHashRef->{'trapVlan'};
        push @vlansToTest, $macDetectionVlan;
        foreach my $currentVlan ( values %{ $self->{_vlans} } ) {
            if (   ( $currentVlan != $trapHashRef->{'trapVlan'} )
                && ( $currentVlan != $macDetectionVlan ) )
            {
                push @vlansToTest, $currentVlan;
            }
        }
        my $found   = 0;
        my $vlanPos = 0;
        my $vlans   = $self->getVlans();
        while ( ( $vlanPos < scalar(@vlansToTest) ) && ( $found == 0 ) ) {
            my $currentVlan = $vlansToTest[$vlanPos];
            my $result      = undef;

            if ( exists( $vlans->{$currentVlan} ) ) {

                #issue correct SNMP query depending on SNMP version
                if ( $self->{_SNMPVersion} eq '3' ) {
                    if ( $self->connectRead() ) {
                        $logger->debug(
                            "BROKEN SNMP fake get_request for dot1dBasePortIfIndex: "
                            ."$OID_dot1dBasePortIfIndex.$dot1dBasePort"
                        );
                        $result = $self->{_sessionRead}->get_request(
                            -varbindlist =>
                                ["$OID_dot1dBasePortIfIndex.$dot1dBasePort"],
                            -contextname => "vlan_$currentVlan"
                        );
                    }
                } else {
                    if ( $self->connectRead() ) {
                        $logger->debug(
                            "BROKEN SNMP fake get_request for dot1dBasePortIfIndex: "
                            ."$OID_dot1dBasePortIfIndex.$dot1dBasePort"
                        );
                        $result
                            = $self->{_sessionRead}->get_request( -varbindlist =>
                                ["$OID_dot1dBasePortIfIndex.$dot1dBasePort"]
                        );
                    } else {
                        $logger->debug(
                            "cannot connect to obtain do1dBasePortIfIndex information in VLAN $currentVlan"
                        );
                    }
                }

                #did we get a result ?
                if (defined($result)
                    && (exists(
                            $result->{
                                "$OID_dot1dBasePortIfIndex.$dot1dBasePort"}
                        )
                    )
                    && ( $result->{"$OID_dot1dBasePortIfIndex.$dot1dBasePort"}
                        ne 'noSuchInstance' )
                    )
                {
                    $trapHashRef->{'trapIfIndex'} = $result->{
                        "$OID_dot1dBasePortIfIndex.$dot1dBasePort"};
                    $logger->debug(
                        "converted dot1dBasePort $dot1dBasePort into ifIndex "
                            . $trapHashRef->{'trapIfIndex'}
                            . " in vlan $currentVlan" );
                    $found = 1;
                } else {
                    $logger->debug(
                        "cannot convert dot1dBasePort $dot1dBasePort into ifIndex in VLAN $currentVlan - "
                            . ( scalar(@vlansToTest) - $vlanPos - 1 )
                            . " more vlans to try" );
                }
            }
            $vlanPos++;
        }
        if ( $found == 0 ) {
            $logger->error(
                "could not convert dot1dBasePort into ifIndex in any VLAN. Setting trapType to unknown"
            );
            $trapHashRef->{'trapType'} = 'unknown';
        }

        # CISCO-PORT-SECURITY-MIB cpsSecureMacAddrViolation
    } elsif (
        ( $trapString
        =~ /BEGIN VARIABLEBINDINGS .+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.4\.1\.9\.9\.315\.0\.0\.1[|]\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.([0-9]+) = .+[|]\.1\.3\.6\.1\.4\.1\.9\.9\.315\.1\.2\.1\.1\.10\.[0-9]+ = $SNMP::MAC_ADDRESS_FORMAT/
        ) || ( $trapString
        =~ /BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.([0-9]+) = .+[|]\.1\.3\.6\.1\.4\.1\.9\.9\.315\.1\.2\.1\.1\.10\.[0-9]+ = $SNMP::MAC_ADDRESS_FORMAT/) ) {

        $trapHashRef->{'trapType'} = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1;
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($2);
        $trapHashRef->{'trapVlan'} = $self->getVlan( $trapHashRef->{'trapIfIndex'} );

        # CISCO-PORT-SECURITY-MIB cpsTrunkSecureMacAddrViolation
    } elsif ( $trapString
        =~ /BEGIN VARIABLEBINDINGS .+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.4\.1\.9\.9\.315\.0\.0\.2[|]\.1\.3\.6\.1\.2\.1\.31\.1\.1\.1\.1\.([0-9]+) = .+[|]\.1\.3\.6\.1\.4\.1\.9\.9\.315\.1\.2\.1\.1\.10\.[0-9]+ = $SNMP::MAC_ADDRESS_FORMAT/ ) {

        $trapHashRef->{'trapType'} = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1;
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($2);
        $trapHashRef->{'trapVlan'} = $self->getVlan( $trapHashRef->{'trapIfIndex'} );

    #  IEEE802dot11-MIB dot11DeauthenticateReason + dot11DeauthenticateStation
    } elsif ( $trapString
        =~ /\.1\.2\.840\.10036\.1\.1\.1\.17\.[0-9]+ = INTEGER: [0-9]+[|]\.1\.2\.840\.10036\.1\.1\.1\.18\.[0-9]+ = $SNMP::MAC_ADDRESS_FORMAT/ ) {

        $trapHashRef->{'trapType'} = 'dot11Deauthentication';
        $trapHashRef->{'trapIfIndex'} = "WIFI";
        $trapHashRef->{'trapMac'} = parse_mac_from_trap($1);

    } else {
        $logger->debug("trap currently not handled");
        $trapHashRef->{'trapType'} = 'unknown';
    }
    return $trapHashRef;
}

# FIXME not properly mocked
sub getAllVlans {
    my ( $self, @ifIndexes ) = @_;
    my $logger = $self->logger;
    my $vlanHashRef;
    if ( !@ifIndexes ) {
        @ifIndexes = $self->getManagedIfIndexes();
    }

    my $OID_vmVlan
        = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';    #CISCO-VLAN-MEMBERSHIP-MIB
    my $OID_vlanTrunkPortNativeVlan
        = '1.3.6.1.4.1.9.9.46.1.6.1.1.5';    #CISCO-VTP-MIB

    if ( !$self->connectRead() ) {
        return $vlanHashRef;
    }
    $logger->debug("BROKEN SNMP fake get_table for vmVlan: $OID_vmVlan");
    my $result = $self->{_sessionRead}->get_table( -baseoid => $OID_vmVlan );
    foreach my $key ( keys %{$result} ) {
        my $vlan = $result->{$key};
        $key =~ /^$OID_vmVlan\.(\d+)$/;
        my $ifIndex = $1;
        if (   ( $vlan ne 'noSuchInstance' )
            && ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) )
        {
            $vlanHashRef->{$ifIndex} = $vlan;
        }
    }
    if ( scalar( keys(%$vlanHashRef) ) < scalar(@ifIndexes) ) {
        $logger->debug(
            "BROKEN SNMP fake get_table for vlanTrunkPortNativeVlan: $OID_vlanTrunkPortNativeVlan"
        );
        $result = $self->{_sessionRead}
            ->get_table( -baseoid => $OID_vlanTrunkPortNativeVlan );
        foreach my $key ( keys %{$result} ) {
            my $vlan = $result->{$key};
            $key =~ /^$OID_vlanTrunkPortNativeVlan\.(\d+)$/;
            my $ifIndex = $1;
            if (   ( $vlan ne 'noSuchInstance' )
                && ( !exists( $vlanHashRef->{$ifIndex} ) )
                && ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) )
            {
                $vlanHashRef->{$ifIndex} = $vlan;
            }
        }
    }
    return $vlanHashRef;
}

# FIXME not properly mocked
sub getVoiceVlan {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_vmVoiceVlanId
        = '1.3.6.1.4.1.9.9.68.1.5.1.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->debug(
        "BROKEN SNMP fake get_request for vmVoiceVlanId: $OID_vmVoiceVlanId.$ifIndex");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_vmVoiceVlanId.$ifIndex"] );
    if ( exists( $result->{"$OID_vmVoiceVlanId.$ifIndex"} )
        && ( $result->{"$OID_vmVoiceVlanId.$ifIndex"} ne 'noSuchInstance' ) )
    {
        return $result->{"$OID_vmVoiceVlanId.$ifIndex"};
    } else {
        return -1;
    }
}

# FIXME not properly mocked
# TODO: if ifIndex doesn't exist, an error should be given
# to reproduce: bin/pfcmd_vlan -getVlan -ifIndex 999 -switch <ip>
sub getVlan {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_vmVlan
        = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->debug("BROKEN SNMP fake get_request for vmVlan: $OID_vmVlan.$ifIndex");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_vmVlan.$ifIndex"] );
    if ( exists( $result->{"$OID_vmVlan.$ifIndex"} )
        && ( $result->{"$OID_vmVlan.$ifIndex"} ne 'noSuchInstance' ) )
    {
        return $result->{"$OID_vmVlan.$ifIndex"};
    } else {

        #this is a trunk port - try to get the trunk ports native VLAN
        my $OID_vlanTrunkPortNativeVlan
            = '1.3.6.1.4.1.9.9.46.1.6.1.1.5';    #CISCO-VTP-MIB
        $logger->debug(
            "BROKEN SNMP fake get_request for vlanTrunkPortNativeVlan: $OID_vlanTrunkPortNativeVlan.$ifIndex"
        );
        my $result = $self->{_sessionRead}->get_request(
            -varbindlist => ["$OID_vlanTrunkPortNativeVlan.$ifIndex"] );
        return $result->{"$OID_vlanTrunkPortNativeVlan.$ifIndex"};
    }
}

# FIXME not properly mocked
sub isLearntTrapsEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_cmnMacAddrLearntEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.1';
    $logger->debug(
        "BROKEN SNMP fake get_request for cmnMacAddrLearntEnable: $OID_cmnMacAddrLearntEnable"
    );
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => [ "$OID_cmnMacAddrLearntEnable.$ifIndex" ] );
    return (
        exists( $result->{"$OID_cmnMacAddrLearntEnable.$ifIndex"} )
            && ( $result->{"$OID_cmnMacAddrLearntEnable.$ifIndex"} ne 'noSuchInstance' )
            && ( $result->{"$OID_cmnMacAddrLearntEnable.$ifIndex"} ne 'noSuchObject' )
            && ( $result->{"$OID_cmnMacAddrLearntEnable.$ifIndex"} == 1 )
    );
}

# FIXME not properly mocked
sub setLearntTrapsEnabled {

    #1 means 'enabled', 2 means 'disabled'
    my ( $self, $ifIndex, $trueFalse ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $OID_cmnMacAddrLearntEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.1';
    $logger->debug(
        "BROKEN SNMP fake set_request for cmnMacAddrLearntEnable: $OID_cmnMacAddrLearntEnable"
    );
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_cmnMacAddrLearntEnable.$ifIndex", Net::SNMP::INTEGER,
            $trueFalse
        ]
    );
    return ( defined($result) );
}

# FIXME not properly mocked
sub isRemovedTrapsEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_cmnMacAddrRemovedEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.2';
    $logger->debug(
        "BROKEN SNMP fake get_request for cmnMacAddrRemovedEnable: $OID_cmnMacAddrRemovedEnable"
    );
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => [ "$OID_cmnMacAddrRemovedEnable.$ifIndex" ] );

    $logger->debug("Override default return. Returning: $REMOVED_TRAPS_ENABLED in MockedSwitch");
    return $REMOVED_TRAPS_ENABLED;
#    return (
#        exists( $result->{"$OID_cmnMacAddrRemovedEnable.$ifIndex"} )
#            && ( $result->{"$OID_cmnMacAddrRemovedEnable.$ifIndex"} ne
#            'noSuchInstance' )
#            && ( $result->{"$OID_cmnMacAddrRemovedEnable.$ifIndex"} == 1 )
#    );
}

# FIXME not properly mocked
sub setRemovedTrapsEnabled {

    #1 means 'enabled', 2 means 'disabled'
    my ( $self, $ifIndex, $trueFalse ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $OID_cmnMacAddrRemovedEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.2';
    $logger->debug(
        "BROKEN SNMP fake set_request for cmnMacAddrRemovedEnable: $OID_cmnMacAddrRemovedEnable"
    );
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_cmnMacAddrRemovedEnable.$ifIndex", Net::SNMP::INTEGER,
            $trueFalse
        ]
    );
    return ( defined($result) );
}

# FIXME not properly mocked
sub isPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    #CISCO-PORT-SECURITY-MIB
    my $OID_cpsIfPortSecurityEnable = '1.3.6.1.4.1.9.9.315.1.2.1.1.1';

    if ( !$self->connectRead() ) {
        return 0;
    }

    #determine if port security is enabled
    $logger->debug(
        "BROKEN SNMP fake get_request for cpsIfPortSecurityEnable: $OID_cpsIfPortSecurityEnable.$ifIndex"
    );
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => [ "$OID_cpsIfPortSecurityEnable.$ifIndex" ] );
    return (
        exists( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} )
            && ( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} ne
            'noSuchInstance' )
            && ( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} ne
            'noSuchObject' )
            && ( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} == 1 )
    );
}

# FIXME not properly mocked
sub _setVlan {
    my ( $self, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = $self->logger;

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $removedTrapsEnabled = $self->isRemovedTrapsEnabled($ifIndex);
    if ($removedTrapsEnabled) {
        $logger->debug("disabling removed traps for port $ifIndex before VLAN change");
        $self->setRemovedTrapsEnabled( $ifIndex, $SNMP::FALSE );
    }

    my $result;
    if ( $self->isTrunkPort($ifIndex) ) {

        $result = $self->setTrunkPortNativeVlan($ifIndex, $newVlan);

        #expirer manuellement la mac-address-table
        $self->clearMacAddressTable( $ifIndex, $oldVlan );

    } else {
        my $OID_vmVlan = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';    #CISCO-VLAN-MEMBERSHIP-MIB
        $logger->debug("BROKEN SNMP fake set_request for vmVlan: $OID_vmVlan");
        $result = $self->{_sessionWrite}->set_request( -varbindlist =>[
            "$OID_vmVlan.$ifIndex", Net::SNMP::INTEGER, $newVlan ] );
    }
    my $returnValue = ( defined($result) );

    if ($removedTrapsEnabled) {
        $logger->debug("re-enabling removed traps for port $ifIndex after VLAN change");
        $self->setRemovedTrapsEnabled( $ifIndex, $SNMP::TRUE );
    }

    return $returnValue;
}

=item setTrunkPortNativeVlan - sets PVID on a trunk port

=cut

# FIXME not properly mocked
sub setTrunkPortNativeVlan {
    my ( $self, $ifIndex, $newVlan ) = @_;
    my $logger = $self->logger;

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $result;
    my $OID_vlanTrunkPortNativeVlan = '1.3.6.1.4.1.9.9.46.1.6.1.1.5';    #CISCO-VTP-MIB
    $logger->debug("BROKEN SNMP fake set_request for vlanTrunkPortNativeVlan: $OID_vlanTrunkPortNativeVlan");
    $result = $self->{_sessionWrite}->set_request( -varbindlist => [
        "$OID_vlanTrunkPortNativeVlan.$ifIndex", Net::SNMP::INTEGER, $newVlan] );

    return $result;

}

# fetch port type
# 1 => static
# 2 => dynamic
# 3 => multivlan
# 4 => trunk
# FIXME not properly mocked
sub getVmVlanType {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return 0;
    }
    my $OID_vmVlanType
        = '1.3.6.1.4.1.9.9.68.1.2.2.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->debug(
        "BROKEN SNMP fake get_request for vmVlanType: $OID_vmVlanType.$ifIndex");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_vmVlanType.$ifIndex"] );
    if ( exists( $result->{"$OID_vmVlanType.$ifIndex"} )
        && ( $result->{"$OID_vmVlanType.$ifIndex"} ne 'noSuchInstance' ) )
    {
        return $result->{"$OID_vmVlanType.$ifIndex"};
    } elsif ( $self->isTrunkPort($ifIndex) ) {
        return 4;
    } else {
        return 0;
    }
}

# FIXME not properly mocked
sub setVmVlanType {
    my ( $self, $ifIndex, $type ) = @_;
    my $logger = $self->logger;
    $logger->info( "setting port $ifIndex vmVlanType from "
            . $self->getVmVlanType($ifIndex)
            . " to $type" );
    if ( !$self->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't change this port VmVlanType"
        );
        return 1;
    }
    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $OID_vmVlanType
        = '1.3.6.1.4.1.9.9.68.1.2.2.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->debug("BROKEN SNMP fake set_request for vmVlanType: $OID_vmVlanType");
    my $result = $self->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_vmVlanType.$ifIndex", Net::SNMP::INTEGER, $type ] );
    return ( defined($result) );
}

=item getMacBridgePortHash

Cisco is very fancy about fetching it's VLAN information. In SNMPv3 the context
is used to specify a VLAN and in SNMPv1/2c an @<vlan> is appended to the
read-only community name when reading.

=cut

# FIXME not properly mocked
sub getMacBridgePortHash {
    my $self              = shift;
    my $vlan              = shift || '';
    my %macBridgePortHash = ();
    my $logger            = $self->logger;
    my $OID_dot1dTpFdbPort       = '1.3.6.1.2.1.17.4.3.1.2';    #BRIDGE-MIB
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB

    if ( !$self->connectRead() ) {
        return %macBridgePortHash;
    }

    #obtain ifPhysAddress array
    my $OID_ifPhysAddress = '1.3.6.1.2.1.2.2.1.6';
    $logger->debug("BROKEN SNMP fake get_table for ifPhysAddress: $OID_ifPhysAddress");
    my $result
        = $self->{_sessionRead}->get_table( -baseoid => $OID_ifPhysAddress );
    my %ifPhysAddressHash;
    foreach my $key ( keys %{$result} ) {
        $key =~ /^$OID_ifPhysAddress\.(\d+)$/;
        my $ifIndex = $1;
        my $mac     = $result->{$key};
        if ( $mac
            =~ /0x([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})/i
            )
        {
            $mac = uc("$1:$2:$3:$4:$5:$6");
            $ifPhysAddressHash{$mac} = $ifIndex;
        }
    }

    #connect to switch with the right VLAN information
    $result = undef;
    my %dot1dBasePortIfIndexHash;

    #issue correct SNMP query depending on SNMP version
    if ( $self->{_SNMPVersion} eq '3' ) {
        $logger->debug(
            "BROKEN SNMP v3 fake get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex"
        );
        $result = $self->{_sessionRead}->get_table(
            -baseoid     => $OID_dot1dBasePortIfIndex,
            -contextname => "vlan_$vlan"
        );
        foreach my $key ( keys %{$result} ) {
            $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
            $dot1dBasePortIfIndexHash{$1} = $result->{$key};
        }
        $logger->debug(
            "BROKEN SNMP v3 fake get_table for dot1dTpFdbPort: $OID_dot1dTpFdbPort");
        $result = $self->{_sessionRead}->get_table(
            -baseoid     => $OID_dot1dTpFdbPort,
            -contextname => "vlan_$vlan"
        );
    } else {

        if ( defined($self->{_sessionRead}) ) {

            #get dot1dBasePort to ifIndex association
            $logger->debug("BROKEN SNMP fake get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex");
            $result = $self->{_sessionRead}->get_table(
                -baseoid => $OID_dot1dBasePortIfIndex );
            foreach my $key ( keys %{$result} ) {
                $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
                $dot1dBasePortIfIndexHash{$1} = $result->{$key};
            }
            $logger->debug("BROKEN SNMP fake get_table for dot1dTpFdbPort: $OID_dot1dTpFdbPort");
            $result = $self->{_sessionRead}->get_table(
                -baseoid => $OID_dot1dTpFdbPort );
        } else {
            $logger->error(
                "cannot connect to obtain do1dBasePortIfIndex information in VLAN $vlan"
            );
        }
    }

    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            if ( exists $dot1dBasePortIfIndexHash{ $result->{$key} } ) {
                $key
                    =~ /^$OID_dot1dTpFdbPort\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
                my $mac = sprintf( "%02X:%02X:%02X:%02X:%02X:%02X",
                    $1, $2, $3, $4, $5, $6 );
                if ( !exists( $ifPhysAddressHash{$mac} ) ) {
                    $macBridgePortHash{$mac}
                        = $dot1dBasePortIfIndexHash{ $result->{$key} };
                }
            }
        }
    }

    return %macBridgePortHash;
}

# FIXME not properly mocked
sub getIfIndexForThisMac {
    my ( $self, $mac ) = @_;
    my $logger   = $self->logger;
    my @macParts = split( ':', $mac );
    my @uplinks  = $self->getUpLinks();
    my $OID_dot1dTpFdbPort       = '1.3.6.1.2.1.17.4.3.1.2';    #BRIDGE-MIB
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB

    my $oid
        = $OID_dot1dTpFdbPort . "."
        . hex( $macParts[0] ) . "."
        . hex( $macParts[1] ) . "."
        . hex( $macParts[2] ) . "."
        . hex( $macParts[3] ) . "."
        . hex( $macParts[4] ) . "."
        . hex( $macParts[5] );

    foreach my $vlan ( values %{ $self->{_vlans} } ) {
        my $result = undef;

        $logger->debug("BROKEN SNMP fake get_request for dot1dTpFdbPort: $oid on switch $self->{'_ip'}, VLAN $vlan");

        if ( $self->{_SNMPVersion} eq '3' ) {
            $result = $self->{_sessionRead}->get_request(
                -varbindlist => [$oid],
                -contextname => "vlan_$vlan"
            );
            if ( defined($result) ) {
                my $dot1dPort = $result->{$oid};
                my $oid       = $OID_dot1dBasePortIfIndex . "." . $dot1dPort;
                $logger->debug("BROKEN SNMP fake get_request: $oid context: vlan_$vlan");
                my $result    = $self->{_sessionRead}->get_request(
                    -varbindlist => [$oid],
                    -contextname => "vlan_$vlan"
                );
                if (   ( defined($result) )
                    && ( grep( { $_ == $result->{$oid} } @uplinks ) == 0 ) )
                {
                    return $result->{$oid};
                }
            }

        } else {

            if ( defined($self->{_sessionRead}) ) {
                $logger->debug("BROKEN SNMP fake get_request: $oid with weird @ connect syntax");
                $result
                    = $self->{_sessionRead}->get_request( -varbindlist => [$oid] );
                if ( defined($result) ) {
                    my $dot1dPort = $result->{$oid};
                    my $oid    = $OID_dot1dBasePortIfIndex . "." . $dot1dPort;
                    $logger->debug("BROKEN SNMP fake get_request: $oid with weird @ connect syntax");
                    my $result = $self->{_sessionRead}->get_request(
                        -varbindlist => [$oid] );
                    if (   ( defined($result) )
                        && ( grep( { $_ == $result->{$oid} } @uplinks ) == 0 )
                        )
                    {
                        return $result->{$oid};
                    }
                }
            } else {
                $logger->error(
                    "cannot connect to obtain do1dTpFdbPort information in VLAN $vlan"
                );
            }
        }

    }
    return -1;
}

# FIXME not properly mocked
sub isMacInAddressTableAtIfIndex {
    my ( $self, $mac, $ifIndex ) = @_;
    my $logger = $self->logger;
    my @macParts = split( ':', $mac );
    my $OID_dot1dTpFdbPort       = '1.3.6.1.2.1.17.4.3.1.2';    #BRIDGE-MIB
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB

    my $oid
        = $OID_dot1dTpFdbPort . "."
        . hex( $macParts[0] ) . "."
        . hex( $macParts[1] ) . "."
        . hex( $macParts[2] ) . "."
        . hex( $macParts[3] ) . "."
        . hex( $macParts[4] ) . "."
        . hex( $macParts[5] );

    my $vlan = $self->getVlan($ifIndex);

    if ( $self->{_SNMPVersion} eq '3' ) {
        $logger->debug("BROKEN SNMP fake get_request for $oid");
        my $result = $self->{_sessionRead}->get_request(
            -varbindlist => [$oid],
            -contextname => "vlan_$vlan"
        );
        if ( defined($result) ) {
            my $dot1dPort = $result->{$oid};
            my $oid       = $OID_dot1dBasePortIfIndex . "." . $dot1dPort;
            $logger->debug("BROKEN SNMP fake get_request for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex");
            my $result = $self->{_sessionRead}->get_request(
                -varbindlist => [$oid],
                -contextname => "vlan_$vlan"
            );
            if ( $result->{$oid} == $ifIndex ) {
                $logger->debug(
                    "mac $mac found on switch $self->{'_ip'}, VLAN $vlan, ifIndex $ifIndex"
                );
                return 1;
            }
        }

    } else {

        if ( defined($self->{_sessionRead}) ) {
            $logger->debug(
                "BROKEN SNMP fake get_request for dot1dBasePortIfIndex: "
                ."$oid on switch $self->{'_ip'}, VLAN $vlan"
            );
            my $result
                = $self->{_sessionRead}->get_request( -varbindlist => [$oid] );
            if ( defined($result) ) {
                my $dot1dPort = $result->{$oid};
                my $oid       = $OID_dot1dBasePortIfIndex . "." . $dot1dPort;
                $logger->debug("BROKEN SNMP fake get_request: $oid context: vlan_$vlan");
                my $result
                    = $self->{_sessionRead}->get_request( -varbindlist => [$oid] );
                if ( $result->{$oid} == $ifIndex ) {
                    $logger->debug(
                        "mac $mac found on switch $self->{'_ip'}, VLAN $vlan, ifIndex $ifIndex"
                    );
                    return 1;
                }
            }
        } else {
            $logger->error(
                "cannot connect to obtain do1dTpFdbPort information in VLAN $vlan"
            );
        }
    }

    $logger->debug(
        "MAC $mac could not be found on switch $self->{'_ip'}, VLAN $vlan, ifIndex $ifIndex"
    );
    return 0;
}

# FIXME not properly mocked
sub isTrunkPort {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $OID_vlanTrunkPortDynamicState
        = "1.3.6.1.4.1.9.9.46.1.6.1.1.13";    #CISCO-VTP-MIB
    if ( !$self->connectRead() ) {
        return 0;
    }
    $logger->debug("BROKEN SNMP fake get_request for vlanTrunkPortDynamicState: $OID_vlanTrunkPortDynamicState");
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => ["$OID_vlanTrunkPortDynamicState.$ifIndex"] );

    $logger->debug("Override default return. Returning: $IS_TRUNK_PORTS in MockedSwitch");
    return $IS_TRUNK_PORTS;
#    return (
#        exists( $result->{"$OID_vlanTrunkPortDynamicState.$ifIndex"} )
#            && ( $result->{"$OID_vlanTrunkPortDynamicState.$ifIndex"} ne
#            'noSuchInstance' )
#            && ( $result->{"$OID_vlanTrunkPortDynamicState.$ifIndex"} == 1 )
#    );
}

=item setModeTrunk - sets a port as mode access or mode trunk

=cut

# FIXME not properly mocked
sub setModeTrunk {
    my ( $self, $ifIndex, $enable ) = @_;
    my $logger = $self->logger;
    my $OID_vlanTrunkPortDynamicState = "1.3.6.1.4.1.9.9.46.1.6.1.1.13";    #CISCO-VTP-MIB

    # $mode = 1 -> switchport mode trunk
    # $mode = 2 -> switchport mode access

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port vlanTrunkPortDynamicState");
        return 1;
    }
    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $truthValue = $enable ? $SNMP::TRUE : $SNMP::FALSE;
    $logger->debug("BROKEN SNMP fake set_request for vlanTrunkPortDynamicState: $OID_vlanTrunkPortDynamicState");
    my $result = $self->{_sessionWrite}->set_request( -varbindlist => [ "$OID_vlanTrunkPortDynamicState.$ifIndex",
        Net::SNMP::INTEGER, $truthValue ] );
    return ( defined($result) );
}

# FIXME not properly mocked
sub getVlans {
    my ($self)          = @_;
    my $vlans           = {};
    my $oid_vtpVlanName = '1.3.6.1.4.1.9.9.46.1.3.1.1.4.1';    #CISCO-VTP-MIB
    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return $vlans;
    }
    $logger->debug("BROKEN SNMP fake get_request for vtpVlanName: $oid_vtpVlanName");
    my $result
        = $self->{_sessionRead}->get_table( -baseoid => $oid_vtpVlanName );
    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            $key =~ /^$oid_vtpVlanName\.(\d+)$/;
            $vlans->{$1} = $result->{$key};
        }
    } else {
        $logger->info( "result is not defined at switch " . $self->{_id} );
    }
    return $vlans;
}

# FIXME not properly mocked
sub isDefinedVlan {
    my ( $self, $vlan ) = @_;
    my $oid_vtpVlanName = '1.3.6.1.4.1.9.9.46.1.3.1.1.4.1';    #CISCO-VTP-MIB
    my $logger = $self->logger;

    if ( !$self->connectRead() ) {
        return 0;
    }
    $logger->debug( "BROKEN SNMP fake get_request for vtpVlanName: $oid_vtpVlanName.$vlan");
    my $result = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$oid_vtpVlanName.$vlan"] );
    return (   defined($result)
            && exists( $result->{"$oid_vtpVlanName.$vlan"} )
            && ( $result->{"$oid_vtpVlanName.$vlan"} ne 'noSuchInstance' ) );
}

# FIXME not properly mocked
sub getUpLinks {
    my $self = shift;
    my @ifIndex;
    my @upLinks;
    my $result;
    my $logger = $self->logger;

    if ( lc(@{ $self->{_uplink} }[0]) eq 'dynamic' ) {

        if ( !$self->connectRead() ) {
            return -1;
        }

        my $oid_cdpGlobalRun
            = '1.3.6.1.4.1.9.9.23.1.3.1'; # Is CDP enabled ? MIB: cdpGlobalRun
        $logger->debug("BROKEN SNMP fake get_table for cdpGlobalRun: $oid_cdpGlobalRun");
        $result = $self->{_sessionRead}
            ->get_table( -baseoid => $oid_cdpGlobalRun );
        if ( defined($result) ) {

            my @cdpRun = values %{$result};
            if ( $cdpRun[0] == 1 ) {

                # CDP is enabled
                my $oid_cdpCachePlateform = '1.3.6.1.4.1.9.9.23.1.2.1.1.8';

                # fetch the upLinks. MIB: cdpCachePlateform
                $logger->debug("BROKEN SNMP fake get_table for cdpCachePlateform: $oid_cdpCachePlateform");
                $result = $self->{_sessionRead}->get_table(

         # we could have chosen another oid since many of them return uplinks.
                    -baseoid => $oid_cdpCachePlateform
                );
                if ( defined($result) ) {
                    foreach my $key ( keys %{$result} ) {
                        if ( !( $result->{$key} =~ /^Cisco IP Phone/ ) ) {
                            $key =~ /^$oid_cdpCachePlateform\.(\d+)\.\d+$/;
                            push @upLinks, $1;
                            $logger->debug("upLink: $1");
                        }
                    }
                } else {
                    $logger->debug(
                        "Problem while determining dynamic uplinks for switch "
                            . $self->{_id}
                            . ": can not read cdpCachePlateform." );
                    return -1;
                }
            } else {
                $logger->debug(
                    "Problem while determining dynamic uplinks for switch "
                        . $self->{_id}
                        . ": based on the config file, uplinks are dynamic but CDP is not enabled on this switch."
                );
                return -1;
            }
        } else {
            $logger->debug(
                      "Problem while determining dynamic uplinks for switch "
                    . $self->{_id}
                    . ": can not read cdpGlobalRun." );
            return -1;
        }
    } else {
        @upLinks = @{ $self->{_uplink} };
    }
    return @upLinks;
}

sub getManagedIfIndexes {
    my $self   = shift;
    my $logger = $self->logger;
    $logger->debug("fake getManagedIfIndexes");
    my @managedIfIndexes;
    my @tmp_managedIfIndexes = $self->SUPER::getManagedIfIndexes();
    foreach my $ifIndex (@tmp_managedIfIndexes) {
        my $port_type = $self->getVmVlanType($ifIndex);
        if ( ( $port_type == 1 ) || ( $port_type == 4 ) ) {  # skip non static
            push @managedIfIndexes, $ifIndex;
        } else {
            $logger->debug(
                "$ifIndex excluded from managed ifIndexes since its port type is not static"
            );
        }
    }
    return @managedIfIndexes;
}

# FIXME not properly mocked
sub getAllMacs {
    my ( $self, @ifIndexes ) = @_;
    my $logger = $self->logger;
    if ( !@ifIndexes ) {
        @ifIndexes = $self->getManagedIfIndexes();
    }
    my $ifIndexVlanMacHashRef;
    my $OID_dot1dTpFdbPort       = '1.3.6.1.2.1.17.4.3.1.2';    #BRIDGE-MIB
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB

    if ( !$self->connectRead() ) {
        return $ifIndexVlanMacHashRef;
    }

    #obtain ifPhysAddress array
    my $OID_ifPhysAddress = '1.3.6.1.2.1.2.2.1.6';
    $logger->debug("BROKEN SNMP fake get_table for ifPhysAddress: $OID_ifPhysAddress");
    my $result
        = $self->{_sessionRead}->get_table( -baseoid => $OID_ifPhysAddress );
    my %ifPhysAddressHash;
    foreach my $key ( keys %{$result} ) {
        $key =~ /^$OID_ifPhysAddress\.(\d+)$/;
        my $ifIndex = $1;
        my $mac     = $result->{$key};
        if ( $mac
            =~ /0x([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})([A-Z0-9]{2})/i
            )
        {
            $mac = uc("$1:$2:$3:$4:$5:$6");
            $ifPhysAddressHash{$mac} = $ifIndex;
        }
    }

    my @vlansOnSwitch   = keys( %{ $self->getVlans() } );
    my @vlansToConsider = values %{ $self->{_vlans} };
    if ( $self->isVoIPEnabled() ) {
        my $OID_vmVoiceVlanId
            = '1.3.6.1.4.1.9.9.68.1.5.1.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
        $logger->debug("BROKEN SNMP fake get_table for vmVoiceVlanId: $OID_vmVoiceVlanId");
        $result = $self->{_sessionRead}
            ->get_table( -baseoid => $OID_vmVoiceVlanId );
        foreach my $vlan ( values %{$result} ) {
            if ( grep( { $_ == $vlan } @vlansToConsider ) == 0 ) {
                push @vlansToConsider, $vlan;
            }
        }
    }
    foreach my $vlan (@vlansToConsider) {
        if ( grep( { $_ == $vlan } @vlansOnSwitch ) > 0 ) {

            #connect to switch with the right VLAN information
            $result = undef;
            my %dot1dBasePortIfIndexHash;

            #issue correct SNMP query depending on SNMP version
            if ( $self->{_SNMPVersion} eq '3' ) {
                $logger->debug("BROKEN SNMP fake v3 get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex");
                $result = $self->{_sessionRead}->get_table(
                    -baseoid     => $OID_dot1dBasePortIfIndex,
                    -contextname => "vlan_$vlan"
                );
                foreach my $key ( keys %{$result} ) {
                    $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
                    $dot1dBasePortIfIndexHash{$1} = $result->{$key};
                }
                $logger->debug("BROKEN SNMP fake v3 get_table for dot1dTpFdbPort: $OID_dot1dTpFdbPort");
                $result = $self->{_sessionRead}->get_table(
                    -baseoid     => $OID_dot1dTpFdbPort,
                    -contextname => "vlan_$vlan"
                );
            } else {
                if ( defined($self->{_sessionRead}) ) {

                    #get dot1dBasePort to ifIndex association
                    $logger->debug("BROKEN SNMP fake get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex");
                    $result = $self->{_sessionRead}->get_table(
                        -baseoid => $OID_dot1dBasePortIfIndex );
                    foreach my $key ( keys %{$result} ) {
                        $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
                        $dot1dBasePortIfIndexHash{$1} = $result->{$key};
                    }
                    $logger->debug("BROKEN SNMP fake get_table for dot1dTpFdbPort: $OID_dot1dTpFdbPort");
                    $result = $self->{_sessionRead}->get_table(
                        -baseoid => $OID_dot1dTpFdbPort );
                } else {
                    $logger->error(
                        "cannot connect to obtain do1dBasePortIfIndex information in VLAN $vlan"
                    );
                }
            }

            if ( defined($result) ) {
                foreach my $key ( keys %{$result} ) {
                    if ( exists $dot1dBasePortIfIndexHash{ $result->{$key} } )
                    {
                        $key
                            =~ /^$OID_dot1dTpFdbPort\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
                        my $mac = sprintf( "%02X:%02X:%02X:%02X:%02X:%02X",
                            $1, $2, $3, $4, $5, $6 );
                        if ( !exists( $ifPhysAddressHash{$mac} ) ) {
                            my $ifIndex = $dot1dBasePortIfIndexHash{ $result
                                    ->{$key} };
                            if ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) {
                                push @{ $ifIndexVlanMacHashRef->{$ifIndex}
                                        ->{$vlan} }, $mac;
                            }
                        }
                    }
                }
            }
        }
    }
    return $ifIndexVlanMacHashRef;
}

sub getPhonesDPAtIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    if ( !$self->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on network device $self->{_id}: no phones returned" );
        return;
    }

    my @phones = ();
    # CDP
    if ($self->supportsCdp()) {
        push @phones, $self->getPhonesCDPAtIfIndex($ifIndex);
    }

    # LLDP
    if ($self->supportsLldp()) {
        push @phones, $self->getPhonesLLDPAtIfIndex($ifIndex);
    }

    # filtering duplicates w/ hashmap (key collisions handles it)
    my %phones = map { $_ => $TRUE } @phones;

    # Log
    if (%phones) {
        $logger->info("We found an IP phone through discovery protocols for ifIndex $ifIndex");
    } else {
        $logger->info("Could not find any IP phones through discovery protocols for ifIndex $ifIndex");
    }
    return keys %phones;
}

# FIXME not properly mocked
sub getPhonesCDPAtIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    $logger->debug("fake getPhonesCDPAtIfIndex ifIndex: $ifIndex");
    my @phones;
    if ( !$self->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch "
                . $self->{_id}
                . ". getPhonesCDPAtIfIndex will return empty list." );
        return @phones;
    }
    my $oid_cdpCacheDeviceId = '1.3.6.1.4.1.9.9.23.1.2.1.1.6';
    my $oid_cdpCachePlatform = '1.3.6.1.4.1.9.9.23.1.2.1.1.8';
    if ( !$self->connectRead() ) {
        return @phones;
    }
    $logger->debug("BROKEN SNMP fake get_next_request for $oid_cdpCachePlatform");
    my $result = $self->{_sessionRead}->get_next_request(
        -varbindlist => ["$oid_cdpCachePlatform.$ifIndex"] );
    foreach my $oid ( keys %{$result} ) {
        if ( $oid =~ /^$oid_cdpCachePlatform\.$ifIndex\.([0-9]+)$/ ) {
            my $cacheDeviceIndex = $1;
            if ( $result->{$oid} =~ /^Cisco IP Phone/ ) {
                $logger->debug("BROKEN SNMP fake get_request for $oid_cdpCacheDeviceId");
                my $MACresult
                    = $self->{_sessionRead}->get_request( -varbindlist =>
                        ["$oid_cdpCacheDeviceId.$ifIndex.$cacheDeviceIndex"]
                    );
                if ($MACresult
                    && ($MACresult->{
                            "$oid_cdpCacheDeviceId.$ifIndex.$cacheDeviceIndex"
                        }
                        =~ /^SEP([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})([0-9A-Z]{2})$/i
                    )
                    )
                {
                    push @phones, lc("$1:$2:$3:$4:$5:$6");
                }
            }
        }
    }
    return @phones;
}

sub isVoIPEnabled {
    my ($self) = @_;
    return ( $self->{_VoIPEnabled} == 1 );
}

# FIXME not properly mocked
sub getManagedPorts {
    my $self       = shift;
    my $logger     = $self->logger;
    my $oid_ifType = '1.3.6.1.2.1.2.2.1.3';                     # MIB: ifTypes
    my $oid_ifName = '1.3.6.1.2.1.31.1.1.1.1';
    my @nonUpLinks;
    my @UpLinks = $self->getUpLinks();    # fetch the UpLink list

    if ( !$self->connectRead() ) {
        return @nonUpLinks;
    }
    $logger->debug("BROKEN SNMP fake get_table for ifType: $oid_ifType");
    my $ifTypes = $self->{_sessionRead}
        ->get_table(    # fetch the ifTypes list of the ports
        -baseoid => $oid_ifType
        );
    if ( defined($ifTypes) ) {

        foreach my $port ( keys %{$ifTypes} ) {
            if ( $ifTypes->{$port} == $SNMP::ETHERNET_CSMACD )
            {           # skip non ethernetCsmacd port type

                $port =~ /^$oid_ifType\.(\d+)$/;
                if ( grep( { $_ == $1 } @UpLinks ) == 0 ) {    # skip UpLinks

                    my $portVlan = $self->getVlan($1);
                    if ( defined $portVlan ) {    # skip port with no VLAN

                        my $port_type = $self->getVmVlanType($1);
                        if ( ( $port_type == 1 ) || ( $port_type == 4 ) )
                        {                         # skip non static

                            if (grep(
                                    { $_ == $portVlan } values %{ $self->{_vlans} } )
                                != 0 )
                            {    # skip port in a non-managed VLAN
                                $logger->debug("BROKEN SNMP fake get_request for ifName: $oid_ifName.$1"
                                );
                                my $ifNames
                                    = $self->{_sessionRead}->get_request(
                                    -varbindlist =>
                                        ["$oid_ifName.$1"]    # MIB: ifNames
                                    );
                                push @nonUpLinks,
                                    $ifNames->{"$oid_ifName.$1"};
                            }
                        }
                    }
                }
            }
        }
    }
    return @nonUpLinks;
}

#obtain hashref from result of getMacAddr
sub _getIfDescMacVlan {
    my ( $self, @macAddr ) = @_;
    my $ifDescMacVlan;
    foreach my $line ( grep( {/DYNAMIC/} @macAddr ) ) {
        my ( $vlan, $mac, $ifDesc ) = unpack( "A4x4A14x16A*", $line );
        $mac =~ s/\./:/g;
        $mac = uc( substr( $mac, 0, 2 ) . ':' . substr( $mac, 2,  5 ) . ':'
                . substr( $mac, 7,  5 ) . ':' . substr( $mac, 12, 2 ) );
        if ( !( $vlan =~ /ALL/i ) ) {
            push @{ $ifDescMacVlan->{$ifDesc}->{$mac} }, int($vlan);
        }
    }
    return $ifDescMacVlan;
}

=item clearMacAddressTable

Warning: this method should _never_ be called in a thread. Net::Appliance::Session is not thread
safe:

L<http://www.cpanforum.com/threads/6909/>

=cut

sub clearMacAddressTable {
    my ( $self, $ifIndex, $vlan ) = @_;
    my $command;
    my $session;
    my $oid_ifName = '1.3.6.1.2.1.31.1.1.1.1';
    my $logger     = $self->logger;
    $logger->info("clearMacAddressTable called.");

    $logger->info("Connect through Telnet and get enabled rights if required.");
    usleep(TELNET_CONNECTION_DELAY);

    # First we fetch ifName(ifIndex)
    if ( !$self->connectRead() ) {
        return 0;
    }

    $logger->debug("BROKEN SNMP fake get_request for ifName: $oid_ifName");
    my $ifNames = $self->{_sessionRead}
        ->get_request( -varbindlist => ["$oid_ifName.$ifIndex"] );
    my $port = $ifNames->{"$oid_ifName.$ifIndex"};

    # then we clear the table with for ifDescr
    $command = "clear mac-address-table interface $port vlan $vlan";

    usleep(TELNET_SMALL_EXCHANGE);
    return 1;
}

# FIXME not properly mocked
sub getMaxMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    #CISCO-PORT-SECURITY-MIB
    my $OID_cpsIfPortSecurityEnable = '1.3.6.1.4.1.9.9.315.1.2.1.1.1';
    my $OID_cpsIfMaxSecureMacAddr   = '1.3.6.1.4.1.9.9.315.1.2.1.1.3';

    if ( !$self->connectRead() ) {
        return -1;
    }

    #determine if port security is enabled
    $logger->debug("BROKEN SNMP fake get_request for cpsIfPortSecurityEnable: $OID_cpsIfPortSecurityEnable.$ifIndex");
    my $result = $self->{_sessionRead}->get_request(
        -varbindlist => [ "$OID_cpsIfPortSecurityEnable.$ifIndex" ] );
    if (( !exists( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} ) )
        || ( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} eq
            'noSuchInstance' )
        )
    {
        $logger->error("ERROR: could not obtain cpsIfPortSecurityEnable");
        return -1;
    }
    if ( $result->{"$OID_cpsIfPortSecurityEnable.$ifIndex"} != 1 ) {
        $logger->debug("cpsIfPortSecurityEnable is not true");
        return -1;
    }

    #determine max number of MAC addresses allowed
    $logger->debug("BROKEN SNMP fake get_request for cpsIfMaxSecureMacAddr: $OID_cpsIfMaxSecureMacAddr.$ifIndex");
    $result = $self->{_sessionRead}->get_request(
        -varbindlist => [ "$OID_cpsIfMaxSecureMacAddr.$ifIndex" ] );
    if (( !exists( $result->{"$OID_cpsIfMaxSecureMacAddr.$ifIndex"} ) )
        || ( $result->{"$OID_cpsIfMaxSecureMacAddr.$ifIndex"} eq
            'noSuchInstance' )
        )
    {
        $logger->error("ERROR: could not obtain cpsIfMaxSecureMacAddr");
        return -1;
    }
    return $result->{"$OID_cpsIfMaxSecureMacAddr.$ifIndex"};

}

=item enablePortSecurityByIfIndex - configure the port with port-security settings

With no VoIP
 switchport port-security maximum 1 vlan access
 switchport port-security
 switchport port-security violation restrict
 switchport port-security mac-adress xxxx.xxxx.xxxx

With VoIP
 switchport port-security maximum 2
 switchport port-security maximum 1 vlan access
 switchport port-security
 switchport port-security violation restrict
 switchport port-security mac-adress xxxx.xxxx.xxxx

=cut

sub enablePortSecurityByIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    $logger->debug("called with ifIndex: $ifIndex");

    my $maxSecureMacTotal;
    my $maxSecureMacVlanAccess = 1;

    if ($self->isVoIPEnabled()) {

        # switchport port-security maximum 2
        $maxSecureMacTotal = 2;
        $self->setPortSecurityMaxSecureMacAddrByIfIndex($ifIndex,$maxSecureMacTotal);

        # switchport port-security maximum 1 vlan access
        $self->setPortSecurityMaxSecureMacAddrVlanAccessByIfIndex($ifIndex,$maxSecureMacVlanAccess);
    } else {

        # switchport port-security maximum 1
        $maxSecureMacTotal = 1;
        $self->setPortSecurityMaxSecureMacAddrByIfIndex($ifIndex,$maxSecureMacTotal);
    }

    # switchport port-security violation restrict
    $self->setPortSecurityViolationActionByIfIndex($ifIndex, $CISCO::DROPNOTIFY);

    # switchport port-security mac-adress xxxx.xxxx.xxxx
    my $macToAuthorize;
    my @macArray = $self->_getMacAtIfIndex($ifIndex);
    if ( !@macArray ) {
        $macToAuthorize = $self->generateFakeMac(0, $ifIndex);
    } else {
        $macToAuthorize = $macArray[0];
    }
    my $vlan = $self->getVlan($ifIndex);
    $self->authorizeMAC( $ifIndex, undef, $macToAuthorize, $vlan, $vlan);

    # switchport port-security
    $self->setPortSecurityEnableByIfIndex($ifIndex, $TRUE);
    return 1;
}

=item disablePortSecurityByIfIndex - remove all the port-security settings on a port

=cut

sub disablePortSecurityByIfIndex {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    $logger->debug("called with ifIndex: $ifIndex");

    # no switchport port-security
    if (! $self->setPortSecurityEnableByIfIndex($ifIndex, $FALSE)) {
        $logger->error("An error occured while disablling port-security on ifIndex $ifIndex");
        return 0;
    }

    # no switchport port-security violation restrict
    if (! $self->setPortSecurityViolationActionByIfIndex($ifIndex, $CISCO::SHUTDOWN)) {
        $logger->error("An error occured while disablling port-security violation restrict in ifIndex $ifIndex");
        return 0;
    }

    # no switchport port-security mac-adress xxxx.xxxx.xxxx
    my $secureMacHashRef = $self->getSecureMacAddresses($ifIndex);
    my $valid = (ref($secureMacHashRef) eq 'HASH');
    my $mac_count = scalar(keys %{$secureMacHashRef});
    if ($valid && $mac_count == 1) {
        my $macToDeAuthorize = (keys %{$secureMacHashRef})[0];
        my $vlan = $self->getVlan($ifIndex);
        if (! $self->authorizeMAC( $ifIndex, $macToDeAuthorize, undef, $vlan, $vlan)) {
            $logger->error("An error occured while de-authorizing $macToDeAuthorize on ifIndex $ifIndex");
            return 0;
        }
    }

    return 1;
}

=item setPortSecurityEnableByIfIndex - enable/disable port-security on a port

=cut

# FIXME not properly mocked
sub setPortSecurityEnableByIfIndex {
    my ( $self, $ifIndex, $enable ) = @_;
    my $logger = $self->logger;
    $logger->debug("called with ifIndex: $ifIndex");

    if ( !$self->isProductionMode() ) {
        $logger->warn("Should set IfPortSecurityEnable on $ifIndex to $enable but the switch is not in production -> Do nothing");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $OID_cpsIfPortSecurityEnable = '1.3.6.1.4.1.9.9.315.1.2.1.1.1';
    my $truthValue = $enable ? $SNMP::TRUE : $SNMP::FALSE;

    $logger->debug("BROKEN SNMP fake set_request for cpsIfPortSecurityEnable: $OID_cpsIfPortSecurityEnable");
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_cpsIfPortSecurityEnable.$ifIndex", Net::SNMP::INTEGER, $truthValue ] );
    return ( defined($result) );
}

=item setPortSecurityMaxSecureMacAddrByIfIndex

Sets the global (data + voice) maximum number of MAC addresses for port-security on a port

=cut

# FIXME not properly mocked
sub setPortSecurityMaxSecureMacAddrByIfIndex {
    my ( $self, $ifIndex, $maxSecureMac ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->warn("Should set IfMaxSecureMacAddr on $ifIndex to $maxSecureMac but the switch is not in production -> Do nothing");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $OID_cpsIfMaxSecureMacAddr = '1.3.6.1.4.1.9.9.315.1.2.1.1.3';

    $logger->debug("BROKEN SNMP fake set_request for IfMaxSecureMacAddr: $OID_cpsIfMaxSecureMacAddr");
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_cpsIfMaxSecureMacAddr.$ifIndex", Net::SNMP::INTEGER, $maxSecureMac ] );
   return ( defined($result) );
}

=item setPortSecurityMaxSecureMacAddrVlanByIfIndex

Sets the maximum number of MAC addresses on the data vlan for port-security on a port

=cut

sub setPortSecurityMaxSecureMacAddrVlanAccessByIfIndex {
    my ( $self, $ifIndex, $maxSecureMac ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->warn("Should set IfMaxSecureMacAddrPerVlan on $ifIndex to $maxSecureMac but the switch is not in production -> Do nothing");
        return 1;
    }

    my $ifName = $self->getIfName($ifIndex);
    if ($ifName eq '') {
        $logger->error( "Can not read ifName for ifIndex $ifIndex, Port-Security maximum can not be set on data Vlan");
        return 0;
    }

    $logger->debug("connecting with Telnet");
    usleep(TELNET_CONNECTION_DELAY);

    usleep(TELNET_LARGE_EXCHANGE);

#    eval {
#        $session->cmd(String => "conf t", Timeout => '10');
#        $session->cmd(String => "int $ifName", Timeout => '10');
#        $session->cmd(String => "switchport port-security maximum $maxSecureMac vlan access", Timeout => '10');
#        $session->cmd(String => "end", Timeout => '10');
#    };
#
#    if ($@) {
#        $logger->error("Error while configuring switchport port-security maximum $maxSecureMac vlan access on ifIndex "
#                       . "$ifIndex. Error message: $!");
#        $session->close();
#        return 0;
#    }
#
#    $session->close();
    return 1;
}

=item setPortSecurityViolationActionByIfIndex

Tells the switch what to do when the number of MAC addresses on the port has exceeded the maximum: shut down the port, send a trap or only allow traffic from the secure port and drop packets from other MAC addresses

=cut

# FIXME not properly mocked
sub setPortSecurityViolationActionByIfIndex {
    my ( $self, $ifIndex, $action ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->warn("Should set IfViolationAction on $ifIndex to $action but the switch is not in production -> Do nothing");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $OID_cpsIfViolationAction = '1.3.6.1.4.1.9.9.315.1.2.1.1.8';

    $logger->debug("BROKEN SNMP fake set_request for IfViolationAction: $OID_cpsIfViolationAction");
    my $result = $self->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_cpsIfViolationAction.$ifIndex", Net::SNMP::INTEGER, $action ] );
    return ( defined($result) );

}

=item setTaggedVlan

Allows all the tagged Vlans on a multi-Vlan port. Used for floating network devices only

=cut

# FIXME not properly mocked
sub setTaggedVlans {
    my ( $self, $ifIndex, @vlans ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port vlanTrunkPortVlansEnabled");
        return 1;
    }

    if (! @vlans) {
        $logger->error("Tagged Vlan list is empty. Cannot set the tagged Vlans on trunk port $ifIndex");
        return 0;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $OID_vlanTrunkPortVlansEnabled   = '1.3.6.1.4.1.9.9.46.1.6.1.1.4';
    my $OID_vlanTrunkPortVlansEnabled2k = '1.3.6.1.4.1.9.9.46.1.6.1.1.17';
    my $OID_vlanTrunkPortVlansEnabled3k = '1.3.6.1.4.1.9.9.46.1.6.1.1.18';
    my $OID_vlanTrunkPortVlansEnabled4k = '1.3.6.1.4.1.9.9.46.1.6.1.1.19';

    my @bits = split //, ("0" x 1024);
    foreach my $t (@vlans) {
        if ($t > 1024) {
            $logger->warn("We do not support Tagged Vlans > 1024 for now on Cisco switches. Sorry... but we could! " .
                      "interested in sponsoring the feature?");
        } else {
            $bits[$t] = "1";
        }
    }
    my $bitString = join ('', @bits);

    my $taggedVlanMembers = pack("B*", $bitString);

    $logger->debug("BROKEN SNMP fake set_request for OID_vlanTrunkPortVlansEnabled: $OID_vlanTrunkPortVlansEnabled");
    my $result = $self->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_vlanTrunkPortVlansEnabled.$ifIndex", Net::SNMP::OCTET_STRING, $taggedVlanMembers,
            "$OID_vlanTrunkPortVlansEnabled2k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 0 x 1024),
            "$OID_vlanTrunkPortVlansEnabled3k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 0 x 1024),
            "$OID_vlanTrunkPortVlansEnabled4k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 0 x 1024) ] );
    return defined($result);
}

=item removeAllTaggedVlan

Removes all the tagged Vlans on a multi-Vlan port. Used for floating network devices only

=cut

# FIXME not properly mocked
sub removeAllTaggedVlans {
    my ( $self, $ifIndex) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port OID_vlanTrunkPortVlansEnabled");
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $OID_vlanTrunkPortVlansEnabled   = '1.3.6.1.4.1.9.9.46.1.6.1.1.4';
    my $OID_vlanTrunkPortVlansEnabled2k = '1.3.6.1.4.1.9.9.46.1.6.1.1.17';
    my $OID_vlanTrunkPortVlansEnabled3k = '1.3.6.1.4.1.9.9.46.1.6.1.1.18';
    my $OID_vlanTrunkPortVlansEnabled4k = '1.3.6.1.4.1.9.9.46.1.6.1.1.19';

    # to reset the tagged Vlans we need to:
    # - set 7F FF ... FF to OID_vlanTrunkPortVlansEnabled
    # - set FF FF ... FF to OID_vlanTrunkPortVlansEnabled2k
    # - set FF FF ... FF to OID_vlanTrunkPortVlansEnabled3k
    # - set FF FF ... FE to OID_vlanTrunkPortVlansEnabled4k
    my $bitString = '0';
    my $bitString4k = '1';
    for (my $i = 1; $i < 1023; $i++) {
        $bitString .= '1';
        $bitString4k .= '1';
    }
    $bitString .= '1';
    $bitString4k .= '0';

    my $taggedVlanMembers = pack("B*", $bitString);
    my $taggedVlanMembers4k = pack("B*", $bitString4k);

    $logger->debug("BROKEN SNMP fake set_request for OID_vlanTrunkPortVlansEnabled: $OID_vlanTrunkPortVlansEnabled");
    my $result = $self->{_sessionWrite}->set_request( -varbindlist => [
        "$OID_vlanTrunkPortVlansEnabled.$ifIndex", Net::SNMP::OCTET_STRING, $taggedVlanMembers,
        "$OID_vlanTrunkPortVlansEnabled2k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 1 x 1024),
        "$OID_vlanTrunkPortVlansEnabled3k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 1 x 1024),
        "$OID_vlanTrunkPortVlansEnabled4k.$ifIndex", Net::SNMP::OCTET_STRING, $taggedVlanMembers4k ] );

    my $returnValue = ( defined($result) );

    return $returnValue;
}

=item enablePortConfigAsTrunk - sets port as multi-Vlan port

=cut

sub enablePortConfigAsTrunk {
    my ($self, $mac, $switch_port, $taggedVlans)  = @_;
    my $logger = $self->logger;

    # switchport mode trunk
    $logger->info("Setting port $switch_port as trunk.");
    if (! $self->setModeTrunk($switch_port, $TRUE)) {
        $logger->error("An error occured while enabling port $switch_port as multi-vlan (trunk)");
        return 0;
    }

    # switchport trunk allowed vlan x,y,z
    $logger->info("Allowing tagged Vlans on port $switch_port");
    if (! $self->setTaggedVlan($switch_port, split(",", $taggedVlans)) ) {
        $logger->error("An error occured while allowing tagged Vlans on trunk port $switch_port");
        return 0;
    }

    # FIXME
    # this is a hack that should be removed. For a mysterious reason if we don't wait 5 sec between the moment we set
    # the port as trunk and the moment we enable linkdown traps, the switch port starts a never ending linkdown/linkup
    # trap cycle. The problem would probably not occur if we could enable only linkdown traps without linkup.
    # But we can't on Cisco's...
    $logger->debug("sleeping for 5 seconds to let the switch digest the change");
    sleep(5);

    return 1;
}

=item disablePortConfigAsTrunk - sets port as non multi-Vlan port

=cut

sub disablePortConfigAsTrunk {
    my ($self, $switch_port) = @_;
    my $logger = $self->logger;

    # switchport mode access
    $logger->info("Setting port $switch_port as non trunk.");
    if (! $self->setModeTrunk($switch_port, $FALSE)) {
        $logger->error("An error occured while disabling port $switch_port as multi-vlan (trunk)");
        return 0;
    }

    # no switchport trunk allowed vlan
    # this setting is not necessary but we thought it would ease the reading of the port configuration if we remove
    # all the tagged vlan when they are not in use (port no longer trunk)
    $logger->info("Disabling tagged Vlans on port $switch_port");
    if (! $self->removeAllTaggedVlan($switch_port)) {
        $logger->warn("An minor issue occured while disabling tagged Vlans on trunk port $switch_port " .
                      "but the port should work.");
    }

    return 1;
}

=item dot1xPortReauthenticate

Forces 802.1x re-authentication of a given ifIndex

ifIndex - ifIndex to force re-authentication on

=cut

sub dot1xPortReauthenticate {
    my ($self, $ifIndex, $mac) = @_;

    return $self->_dot1xPortReauthenticate($ifIndex);
}

=item _dot1xPortReauthenticate

Actual implementation.
Allows callers to refer to this implementation even though someone along the way override the above call.

=cut

sub _dot1xPortReauthenticate {
    my ($self, $ifIndex) = @_;
    my $logger = $self->logger;

    $logger->info("Trying generic MIB to force 802.1x port re-authentication. Your mileage may vary. "
        . "If it doesn't work open a bug report with your hardware type.");

    my $oid_dot1xPaePortReauthenticate = "1.0.8802.1.1.1.1.1.2.1.5"; # from IEEE8021-PAE-MIB

    if (!$self->connectWrite()) {
        return 0;
    }

    $logger->trace("SNMP set_request force dot1xPaePortReauthenticate on ifIndex: $ifIndex");
    my $result = $self->{_sessionWrite}->set_request(-varbindlist => [
        "$oid_dot1xPaePortReauthenticate.$ifIndex", Net::SNMP::INTEGER, 1
    ]);

    if (!defined($result)) {
        $logger->error("got an SNMP error trying to force 802.1x re-authentication: ".$self->{_sessionWrite}->error);
    }

    return (defined($result));
}

sub getMinOSVersion {
    my ($self) = @_;
    my $logger = $self->logger;
    return '12.2(25)SEE2';
}

# FIXME not properly mocked
sub getAllSecureMacAddresses {
    my ($self) = @_;
    my $logger = $self->logger;
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';

    my $secureMacAddrHashRef = {};
    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->debug(
        "BROKEN SNMP fake get_table for cpsIfVlanSecureMacAddrRowStatus: $oid_cpsIfVlanSecureMacAddrRowStatus"
    );
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsIfVlanSecureMacAddrRowStatus" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$oid_cpsIfVlanSecureMacAddrRowStatus\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
            my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x",
                $2, $3, $4, $5, $6, $7 );
            my $oldVlan = $8;
            my $ifIndex = $1;
            push @{ $secureMacAddrHashRef->{$oldMac}->{$ifIndex} }, $oldVlan;
        }
    }

    return $secureMacAddrHashRef;
}

# FIXME not properly mocked
sub isDynamicPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $oid_cpsIfVlanSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.3.1.3';

    if ( !$self->connectRead() ) {
        return 0;
    }
    if ( !$self->isPortSecurityEnabled($ifIndex) ) {
        $logger->debug("port security is not enabled");
        return 0;
    }

    $logger->debug("BROKEN SNMP fake get_table for cpsIfVlanSecureMacAddrType: $oid_cpsIfVlanSecureMacAddrType");
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsIfVlanSecureMacAddrType.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if (   ( $result->{$oid_including_mac} == 1 )
            || ( $result->{$oid_including_mac} == 3 ) )
        {
            return 0;
        }
    }

    return 1;
}

# FIXME not properly mocked
sub isStaticPortSecurityEnabled {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $oid_cpsIfVlanSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.3.1.3';

    if ( !$self->connectRead() ) {
        return 0;
    }
    if ( !$self->isPortSecurityEnabled($ifIndex) ) {
        $logger->info("port security is not enabled");
        return 0;
    }

    $logger->debug("BROKEN SNMP fake get_table for cpsIfVlanSecureMacAddrType: $oid_cpsIfVlanSecureMacAddrType");
    my $result = $self->{_sessionRead}
        ->get_table( -baseoid => "$oid_cpsIfVlanSecureMacAddrType.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if (   ( $result->{$oid_including_mac} == 1 )
            || ( $result->{$oid_including_mac} == 3 ) )
        {
            return 1;
        }
    }

    return 0;
}

# FIXME not properly mocked
sub getSecureMacAddresses {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';

    my $secureMacAddrHashRef = {};
    if ( !$self->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->debug("SNMP get_table for cpsIfVlanSecureMacAddrRowStatus: $oid_cpsIfVlanSecureMacAddrRowStatus");
    my $result = $self->{_sessionRead}->get_table(
        -baseoid => "$oid_cpsIfVlanSecureMacAddrRowStatus.$ifIndex" );
    foreach my $oid_including_mac ( keys %{$result} ) {
        if ( $oid_including_mac
            =~ /^$oid_cpsIfVlanSecureMacAddrRowStatus\.$ifIndex\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$/
            )
        {
            my $oldMac = sprintf( "%02x:%02x:%02x:%02x:%02x:%02x",
                $1, $2, $3, $4, $5, $6 );
            my $oldVlan = $7;
            push @{ $secureMacAddrHashRef->{$oldMac} }, int($oldVlan);
        }
    }

    return $secureMacAddrHashRef;
}

# FIXME not properly mocked
sub authorizeMAC {
    my ( $self, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = $self->logger;
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';

    if ( !$self->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't add an entry to the SecureMacAddrTable"
        );
        return 1;
    }

    if ( !$self->connectWrite() ) {
        return 0;
    }

    my $voiceVlan = $self->getVoiceVlan($ifIndex);
    if ( ( $deauthVlan == $voiceVlan ) || ( $authVlan == $voiceVlan ) ) {
        $logger->error(
            "ERROR: authorizeMAC called with voice VLAN .... this should not have happened ... we won't add an entry to the SecureMacAddrTable"
        );
        return 1;
    }

    my @oid_value;
    if ($deauthMac) {
        my @macArray = split( /:/, $deauthMac );
        my $completeOid
            = $oid_cpsIfVlanSecureMacAddrRowStatus . "." . $ifIndex;
        foreach my $macPiece (@macArray) {
            $completeOid .= "." . hex($macPiece);
        }
        $completeOid .= "." . $deauthVlan;
        push @oid_value, ( $completeOid, Net::SNMP::INTEGER, 6 );
    }
    if ($authMac) {
        my @macArray = split( /:/, $authMac );
        my $completeOid
            = $oid_cpsIfVlanSecureMacAddrRowStatus . "." . $ifIndex;
        foreach my $macPiece (@macArray) {
            $completeOid .= "." . hex($macPiece);
        }
        # FIXME: it should be authVlan, doesn't it?
        $completeOid .= "." . $deauthVlan;
        push @oid_value, ( $completeOid, Net::SNMP::INTEGER, 4 );
    }

    if ( scalar(@oid_value) > 0 ) {
        $logger->debug("BROKEN SNMP fake set_request for cpsIfVlanSecureMacAddrRowStatus");
        my $result = $self->{_sessionWrite}
            ->set_request( -varbindlist => \@oid_value );
    }
    return 1;
}

sub NasPortToIfIndex {
    my ($self, $NAS_port) = @_;
    my $logger = $self->logger;

    if ($NAS_port =~ s/^5/1/) {
        return $NAS_port;
    } else {
        $logger->warn("Unknown NAS-Port format. ifIndex translation could have failed. "
            ."VLAN re-assignment and switch/port accounting will be affected.");
    }
    return $NAS_port;
}

=item handleReAssignVlanTrapForWiredMacAuth

=cut

sub handleReAssignVlanTrapForWiredMacAuth {
    my ($self, $ifIndex, $mac) = @_;
    my $logger = $self->logger;

    my $switch_ip = $self->{'_ip'};
    my @locationlog = locationlog_view_open_switchport_no_VoIP( $switch_ip, $ifIndex );
    if (!(@locationlog) || !defined($locationlog[0]->{'mac'}) || ($locationlog[0]->{'mac'} eq '' )) {
        $logger->warn( "received reAssignVlan trap on $switch_ip ifIndex $ifIndex but can't determine non VoIP MAC");
        return;
    }

    if (!defined($mac)) {
        $mac = $locationlog[0]->{'mac'};
    }
    my $hasPhone = $self->hasPhoneAtIfIndex($ifIndex);

    # TODO extract that behavior in a method call in pf::role so it can be overridden easily
    if ( !$hasPhone ) {
        $logger->info( "no VoIP phone is currently connected at " . $switch_ip
            . " ifIndex $ifIndex. Flipping port admin status"
        );
        $self->bouncePort($ifIndex);

    } else {

        $logger->info(
            "A VoIP phone is currently connected at $switch_ip ifIndex $ifIndex. Leaving everything as it is."
        );
        # TODO perform CoA (when implemented)

        my @security_events = security_event_view_open_desc($mac);
        if ( scalar(@security_events) > 0 ) {
            my %message;
            $message{'subject'} = "VLAN isolation of $mac behind VoIP phone";
            $message{'message'} = "The following computer has been isolated behind a VoIP phone\n";
            $message{'message'} .= "MAC: $mac\n";

            my $node_info = node_view($mac);
            $message{'message'} .= "Owner: " . $node_info->{'pid'} . "\n";
            $message{'message'} .= "Computer Name: " . $node_info->{'computername'} . "\n";
            $message{'message'} .= "Notes: " . $node_info->{'notes'} . "\n";
            $message{'message'} .= "Switch: " . $switch_ip . "\n";
            $message{'message'} .= "Port (ifIndex): " . $ifIndex . "\n\n";
            $message{'message'} .= "The security event details are\n";

            foreach my $security_event (@security_events) {
                $message{'message'} .= "Description: "
                    . $security_event->{'description'} . "\n";
                $message{'message'} .= "Start: "
                    . $security_event->{'start_date'} . "\n";
            }
            $logger->info(
                "sending email to admin regarding isolation of $mac behind VoIP phone"
            );
            # put the use statement here because we'll be able to get rid of it when refactoring this piece
            use pf::util;
            pfmailer(%message);
        }
    }
}

=item getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

=cut

sub getVoipVsa {
    my ($self) = @_;
    my $logger = $self->logger;

    return ('Cisco-AVPair' => "device-traffic-class=voice");
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    return $TRUE;
}

=item supporteddeauthTechniques

return Default Deauthentication Method

=cut

sub supporteddeauthTechniques {
    my ( $self ) = @_;

    return $TRUE;
}

=item deauthenticateMacDefault

return Default Deauthentication Default technique

=cut

sub deauthenticateMacDefault {
    my ( $self ) = @_;
    my $logger = $self->logger;

    $logger->warn("Unimplemented! First, make sure your configuration is ok. "
        . "If it is then we don't support your hardware. Open a bug report with your hardware type.");
    return $FALSE;
}

=item GetIfIndexByNasPortId

return IfIndexByNasPortId

=cut

sub getIfIndexByNasPortId {
    my ($self ) = @_;
    return $FALSE;
}
=item extractVLAN

Extract VLAN from the radius attributes.

=cut

sub extractVLAN {
    my ($self, $radius_request) = @_;
    my $logger = $self->logger;
    $logger->warn("Not implemented");
    return;
}

=item wiredeauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub wiredeauthTechniques {
    my ($self, $method, $connection_type) = @_;
    my $logger = $self->logger;
    return $TRUE;
}

=item parseRequest

Takes FreeRADIUS' RAD_REQUEST hash and process it to return
NAS Port type (Ethernet, Wireless, etc.)
Network Device IP
EAP
MAC
NAS-Port (port)
User-Name

=cut

sub parseRequest {
    my ($self, $radius_request) = @_;
    my $client_mac = clean_mac($radius_request->{'Calling-Station-Id'});
    my $user_name       = $radius_request->{'PacketFence-UserNameAttribute'} || $radius_request->{'TLS-Client-Cert-Subject-Alt-Name-Upn'} || $radius_request->{'TLS-Client-Cert-Common-Name'} || $radius_request->{'User-Name'};
    my $nas_port_type = $radius_request->{'NAS-Port-Type'};
    my $port = $radius_request->{'NAS-Port'};
    my $eap_type = 0;
    if (exists($radius_request->{'EAP-Type'})) {
        $eap_type = $radius_request->{'EAP-Type'};
    }
    my $nas_port_id;
    if (defined($radius_request->{'NAS-Port-Id'})) {
        $nas_port_id = $radius_request->{'NAS-Port-Id'};
    }
    return ($nas_port_type, $eap_type, $client_mac, $port, $user_name, $nas_port_id, undef, $nas_port_id);
}

sub getAcceptForm {
    my ( $self, $mac, $destination_url, $portalSession ) = @_;
    return "";
}

=item parseExternalPortalRequest

Parse external portal request using URI and it's parameters then return an hash reference with the appropriate parameters

See L<pf::web::externalportal::handle>

=cut

sub parseExternalPortalRequest {
    my ( $self, $r, $req ) = @_;

    # Using a hash to contain external portal parameters
    my %params = ();

    return \%params;
}

=item deauth_source_ip

Computes which IP should be used as source IP address for the deauthentication

Takes into account the active/active clustering and centralized deauth

=cut

sub deauth_source_ip {
    my ($self) = @_;
    return "";
}

=item returnRoleAttributes

Return the specific role attribute of the switch.

=cut

sub returnRoleAttributes {
    my ($self, $role) = @_;
    return ($self->returnRoleAttribute() => $role);
}

=item handleRadiusDeny

Return RLM_MODULE_USERLOCK if the vlan id is -1

=cut

sub handleRadiusDeny {
    my ($self, $args) =@_;
    my $logger = $self->logger();

    if (defined($args->{'vlan'}) && $args->{'vlan'} == -1) {
        $logger->info("According to rules in fetchRoleForNode this node must be kicked out. Returning USERLOCK");
        $self->disconnectRead();
        $self->disconnectWrite();
        return [ $RADIUS::RLM_MODULE_USERLOCK, ('Reply-Message' => "This node is not allowed to use this service") ];
    }
    return undef;
}

=item cache

Return the cache for the namespace switch

=cut

sub cache {
   my ($self) = @_;
   return pf::CHI->new( namespace => 'switch' );
}

=item cache_distributed

Returns the distributed cache for the switch namespace

=cut

sub cache_distributed {
    my ( $self ) = @_;
    return pf::CHI->new( namespace => 'switch_distributed' );
}

=item returnAuthorizeWrite

Return RADIUS attributes to allow write access

=cut

sub returnAuthorizeWrite {
    my ($self, $args) = @_;
    return [ $RADIUS::RLM_MODULE_FAIL, ( 'Reply-Message' => "PacketFence does not support this switch for enable access login" ) ];

}

=item returnAuthorizeRead

Return RADIUS attributes to allow read access

=cut

sub returnAuthorizeRead {
    my ($self, $args) = @_;
    return [ $RADIUS::RLM_MODULE_FAIL, ( 'Reply-Message' => "PacketFence does not support this switch for enable access login" ) ];
}

=item setSession

Create a session id and save in in the locationlog.

=cut

sub setSession {
    my($args) = @_;
    my $mac = $args->{'mac'};
    my $session_id = generate_session_id(6);
    my $chi = pf::CHI->new(namespace => 'httpd.portal');
    $chi->set($session_id,{
        client_mac => $mac,
        wlan => $args->{'ssid'},
        switch_id => $args->{'switch'}->{'_id'},
    });
    pf::locationlog::locationlog_set_session($mac, $session_id);
    return $session_id;
}

=item getUrlByName

Get the switch-specific url of a given global role in switches.conf

=cut

sub getUrlByName {
    my ($self, $roleName) = @_;
    my $logger = $self->logger;

    # skip if not defined or empty
    return if (!defined($self->{'_urls'}) || !%{$self->{'_urls'}});

    # return if found
    return $self->{'_urls'}->{$roleName} if (defined($self->{'_urls'}->{$roleName}));

    # otherwise log and return undef
    $logger->trace("(".$self->{_id}.") No parameter ${roleName}Url found in conf/switches.conf");
    return;
}


sub shouldUseCoA {
    my ($self, $args) = @_;
    # Roles are configured and the user should have one
    return (defined($args->{role}) && isenabled($self->{_RoleMap}) && isenabled($self->{_useCoA}));
}


sub externalPortalEnforcement {
    my ( $self ) = @_;
    my $logger = pf::log::get_logger;

    return $TRUE if ( $self->supportsExternalPortal && isenabled($self->{_ExternalPortalEnforcement}) );

    $logger->info("External portal enforcement either not supported '" . $self->supportsExternalPortal . "' or not configured '" . $self->{_ExternalPortalEnforcement} . "' on network equipment '" . $self->{_id} . "'");
    return $FALSE;
}

=item getLldpLocPortDesc

Query the switch for lldpLocPortDesc table and cache the result

=cut

sub getLldpLocPortDesc {
    my ( $self ) = @_;
    my $logger = $self->logger;

    # if can't SNMP read abort
    return if ( !$self->connectRead() );

    my $oid_lldpLocPortDesc = '1.0.8802.1.1.2.1.3.7.1.4'; # from LLDP-MIB
    $logger->trace("SNMP get_table for lldpLocPortDesc: $oid_lldpLocPortDesc");
    my $cache = $self->cache_distributed;
    my $result = $cache->compute($self->{'_id'} . "-" . $oid_lldpLocPortDesc, sub { $self->{_sessionRead}->get_table( -baseoid => $oid_lldpLocPortDesc, -maxrepetitions  => 1 ) } );
    # here's what we are getting here. Looking for the last element of the OID: lldpRemLocalPortNum
    # iso.0.8802.1.1.2.1.3.7.1.4.10 = STRING: "FastEthernet1/0/8"
    # iso.0.8802.1.1.2.1.3.7.1.4.11 = STRING: "FastEthernet1/0/9"
    # iso.0.8802.1.1.2.1.3.7.1.4.12 = STRING: "FastEthernet1/0/10"
    # iso.0.8802.1.1.2.1.3.7.1.4.13 = STRING: "FastEthernet1/0/11"
    # NOTE: We set the maxrepetitions to '1' to use 'get-next-requests' instead of 'get-bulk-requests' which tend to return empty results if response is to big

    return $result;
}

=item ifIndexToLldpLocalPort

Translate an ifIndex into an LLDP Local Port number.

We use ifDescr to lookup the lldpRemLocalPortNum in the lldpLocPortDesc table.

=cut

sub ifIndexToLldpLocalPort {
    my ( $self, $ifIndex ) = @_;
    my $logger = $self->logger;

    # if can't SNMP read abort
    return if ( !$self->connectRead() );

    my $ifDescr = $self->getIfDesc($ifIndex);
    return if (!defined($ifDescr) || $ifDescr eq '');

    # Get lldpLocPortDesc
    my $oid_lldpLocPortDesc = '1.0.8802.1.1.2.1.3.7.1.4'; # from LLDP-MIB
    my $result = $self->getLldpLocPortDesc();

    foreach my $entry ( keys %{$result} ) {
        if ( $result->{$entry} eq $ifDescr ) {
            if ( $entry =~ /^$oid_lldpLocPortDesc\.([0-9]+)$/ ) {
                return $1;
            }
        }
    }

    # nothing found
    return;
}

=item invalidate_distributed_cache

Invalidate the distributed cache for a given switch object

=cut

sub invalidate_distributed_cache {
    my ( $self ) = @_;
    my $logger = $self->logger;

    $logger->info("Invalidating distributed switch cache for switch '" . $self->{_id} . "'");

    if ( $self->{_id} =~ /\// ) {
        $logger->info("Processing switch range '" . $self->{_id} . "'");
        my $ip = new Net::IP($self->{_id});
        do {
            $logger->info("Invalidating distributed switch cache for switch '" . $ip->ip() . "' part of switch range '" . $self->{_id} . "'");
            $self->remove_switch_from_cache($ip->ip());
        } while (++$ip);
    } else {
        $self->remove_switch_from_cache($self->{_id});
    }
}

=item remove_switch_from_cache

Remove all switch distributed cache keys for a given switch

=cut

sub remove_switch_from_cache {
    my ( $self, $key ) = @_;
    my $logger = $self->logger;

    my $cache = $self->cache_distributed;
    my %cache_content = $cache->get_keys();

    foreach ( keys %cache_content ) {
        $cache->remove($_) if $_ =~ /^$key-/;
    }
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
