package pf::SNMP;

=head1 NAME

pf::SNMP - Object oriented module to access SNMP enabled network switches

=head1 DESCRIPTION

The pf::SNMP module implements an object oriented interface to access
SNMP enabled network switches. This module only contains some basic
functionnality and is meant to be subclassed.

=cut

use strict;
use warnings;
use diagnostics;

use Carp;
use Net::SNMP;
use Log::Log4perl;
use Data::Dumper;

our $VERSION = v1.7.0.6;

use pf::config;
use pf::locationlog;
use pf::node;

=head1 METHODS

=over

=cut

sub new {
    my ( $class, %argv ) = @_;
    my $this = bless {
        '_customVlan1'              => undef,
        '_customVlan2'              => undef,
        '_customVlan3'              => undef,
        '_customVlan4'              => undef,
        '_customVlan5'              => undef,
        '_dbHostname'               => undef,
        '_dbName'                   => undef,
        '_dbPassword'               => undef,
        '_dbUser'                   => undef,
        '_error'                    => undef,
        '_guestVlan'                => undef,
        '_htaccessPwd'              => undef,
        '_htaccessUser'             => undef,
        '_ip'                       => undef,
        '_isolationVlan'            => undef,
        '_macDetectionVlan'         => undef,
        '_macSearchesMaxNb'         => undef,
        '_macSearchesSleepInterval' => undef,
        '_mode'                     => undef,
        '_mysqlConnection'          => undef,
        '_normalVlan'               => undef,
        '_registrationVlan'         => undef,
        '_sessionRead'              => undef,
        '_sessionWrite'             => undef,
        '_SNMPAuthPasswordRead'     => undef,
        '_SNMPAuthPasswordTrap'     => undef,
        '_SNMPAuthPasswordWrite'    => undef,
        '_SNMPAuthProtocolRead'     => undef,
        '_SNMPAuthProtocolTrap'     => undef,
        '_SNMPAuthProtocolWrite'    => undef,
        '_SNMPCommunityRead'        => undef,
        '_SNMPCommunityTrap'        => undef,
        '_SNMPCommunityWrite'       => undef,
        '_SNMPEngineID'             => undef,
        '_SNMPPrivPasswordRead'     => undef,
        '_SNMPPrivPasswordTrap'     => undef,
        '_SNMPPrivPasswordWrite'    => undef,
        '_SNMPPrivProtocolRead'     => undef,
        '_SNMPPrivProtocolTrap'     => undef,
        '_SNMPPrivProtocolWrite'    => undef,
        '_SNMPUserNameRead'         => undef,
        '_SNMPUserNameTrap'         => undef,
        '_SNMPUserNameWrite'        => undef,
        '_SNMPVersion'              => 1,
        '_SNMPVersionTrap'          => 1,
        '_cliEnablePwd'             => undef,
        '_cliPwd'                   => undef,
        '_cliUser'                  => undef,
        '_cliTransport'             => undef,
        '_uplink'                   => undef,
        '_vlans'                    => undef,
        '_voiceVlan'                => undef,
        '_VoIPEnabled'              => undef
    }, $class;

    foreach ( keys %argv ) {
        if (/^-?SNMPCommunityRead$/i) {
            $this->{_SNMPCommunityRead} = $argv{$_};
        } elsif (/^-?SNMPCommunityTrap$/i) {
            $this->{_SNMPCommunityTrap} = $argv{$_};
        } elsif (/^-?SNMPCommunityWrite$/i) {
            $this->{_SNMPCommunityWrite} = $argv{$_};
        } elsif (/^-?customVlan1$/i) {
                    $this->{_customVlan1} = $argv{$_};
        } elsif (/^-?customVlan2$/i) {
                    $this->{_customVlan2} = $argv{$_};
        } elsif (/^-?customVlan2$/i) {
                    $this->{_customVlan2} = $argv{$_};
        } elsif (/^-?customVlan3$/i) {
                    $this->{_customVlan3} = $argv{$_};
        } elsif (/^-?customVlan4$/i) {
                    $this->{_customVlan4} = $argv{$_};
        } elsif (/^-?customVlan5$/i) {
                    $this->{_customVlan5} = $argv{$_};
        } elsif (/^-?dbHostname$/i) {
            $this->{_dbHostname} = $argv{$_};
        } elsif (/^-?dbName$/i) {
            $this->{_dbName} = $argv{$_};
        } elsif (/^-?dbPassword$/i) {
            $this->{_dbPassword} = $argv{$_};
        } elsif (/^-?dbUser$/i) {
            $this->{_dbUser} = $argv{$_};
        } elsif (/^-?guestVlan$/i) {
            $this->{_guestVlan} = $argv{$_};
        } elsif (/^-?htaccessPwd$/i) {
            $this->{_htaccessPwd} = $argv{$_};
        } elsif (/^-?htaccessUser$/i) {
            $this->{_htaccessUser} = $argv{$_};
        } elsif (/^-?ip$/i) {
            $this->{_ip} = $argv{$_};
        } elsif (/^-?isolationVlan$/i) {
            $this->{_isolationVlan} = $argv{$_};
        } elsif (/^-?macDetectionVlan$/i) {
            $this->{_macDetectionVlan} = $argv{$_};
        } elsif (/^-?macSearchesMaxNb$/i) {
            $this->{_macSearchesMaxNb} = $argv{$_};
        } elsif (/^-?macSearchesSleepInterval$/i) {
            $this->{_macSearchesSleepInterval} = $argv{$_};
        } elsif (/^-?mode$/i) {
            $this->{_mode} = $argv{$_};
        } elsif (/^-?normalVlan$/i) {
            $this->{_normalVlan} = $argv{$_};
        } elsif (/^-?registrationVlan$/i) {
            $this->{_registrationVlan} = $argv{$_};
        } elsif (/^-?SNMPAuthPasswordRead$/i) {
            $this->{_SNMPAuthPasswordRead} = $argv{$_};
        } elsif (/^-?SNMPAuthPasswordTrap$/i) {
            $this->{_SNMPAuthPasswordTrap} = $argv{$_};
        } elsif (/^-?SNMPAuthPasswordWrite$/i) {
            $this->{_SNMPAuthPasswordWrite} = $argv{$_};
        } elsif (/^-?SNMPAuthProtocolRead$/i) {
            $this->{_SNMPAuthProtocolRead} = $argv{$_};
        } elsif (/^-?SNMPAuthProtocolTrap$/i) {
            $this->{_SNMPAuthProtocolTrap} = $argv{$_};
        } elsif (/^-?SNMPAuthProtocolWrite$/i) {
            $this->{_SNMPAuthProtocolWrite} = $argv{$_};
        } elsif (/^-?SNMPPrivPasswordRead$/i) {
            $this->{_SNMPPrivPasswordRead} = $argv{$_};
        } elsif (/^-?SNMPPrivPasswordTrap$/i) {
            $this->{_SNMPPrivPasswordTrap} = $argv{$_};
        } elsif (/^-?SNMPPrivPasswordWrite$/i) {
            $this->{_SNMPPrivPasswordWrite} = $argv{$_};
        } elsif (/^-?SNMPPrivProtocolRead$/i) {
            $this->{_SNMPPrivProtocolRead} = $argv{$_};
        } elsif (/^-?SNMPPrivProtocolTrap$/i) {
            $this->{_SNMPPrivProtocolTrap} = $argv{$_};
        } elsif (/^-?SNMPPrivProtocolWrite$/i) {
            $this->{_SNMPPrivProtocolWrite} = $argv{$_};
        } elsif (/^-?SNMPUserNameRead$/i) {
            $this->{_SNMPUserNameRead} = $argv{$_};
        } elsif (/^-?SNMPUserNameTrap$/i) {
            $this->{_SNMPUserNameTrap} = $argv{$_};
        } elsif (/^-?SNMPUserNameWrite$/i) {
            $this->{_SNMPUserNameWrite} = $argv{$_};
        } elsif (/^-?cliEnablePwd$/i) {
            $this->{_cliEnablePwd} = $argv{$_};
        } elsif (/^-?cliPwd$/i) {
            $this->{_cliPwd} = $argv{$_};
        } elsif (/^-?cliUser$/i) {
            $this->{_cliUser} = $argv{$_};
        } elsif (/^-?cliTransport$/i) {
            $this->{_cliTransport} = $argv{$_};
        } elsif (/^-?uplink$/i) {
            $this->{_uplink} = $argv{$_};
        } elsif (/^-?SNMPEngineID$/i) {
            $this->{_SNMPEngineID} = $argv{$_};
        } elsif (/^-?SNMPVersion$/i) {
            $this->{_SNMPVersion} = $argv{$_};
        } elsif (/^-?SNMPVersionTrap$/i) {
            $this->{_SNMPVersionTrap} = $argv{$_};
        } elsif (/^-?vlans$/i) {
            $this->{_vlans} = $argv{$_};
        } elsif (/^-?voiceVlan$/i) {
            $this->{_voiceVlan} = $argv{$_};
        } elsif (/^-?VoIPEnabled$/i) {
            $this->{_VoIPEnabled} = $argv{$_};
        }
    }
    return $this;
}

=item isUpLink - determine is a given ifIndex is connected to another switch

=cut 

sub isUpLink {
    my ( $this, $ifIndex ) = @_;
    return (   ( defined( $this->{_uplink} ) )
            && ( grep( { $_ == $ifIndex } @{ $this->{_uplink} } ) == 1 ) );
}

=item connectRead - establish read connection to switch

=cut

sub connectRead {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( defined( $this->{_sessionRead} ) ) {
        return 1;
    }
    $logger->debug( "opening SNMP v"
            . $this->{_SNMPVersion}
            . " read connection to $this->{_ip}" );
    if ( $this->{_SNMPVersion} eq '3' ) {
        ( $this->{_sessionRead}, $this->{_error} ) = Net::SNMP->session(
            -hostname     => $this->{_ip},
            -version      => $this->{_SNMPVersion},
            -username     => $this->{_SNMPUserNameRead},
            -timeout      => 2,
            -retries      => 1,
            -authprotocol => $this->{_SNMPAuthProtocolRead},
            -authpassword => $this->{_SNMPAuthPasswordRead},
            -privprotocol => $this->{_SNMPPrivProtocolRead},
            -privpassword => $this->{_SNMPPrivPasswordRead}
        );
    } else {
        ( $this->{_sessionRead}, $this->{_error} ) = Net::SNMP->session(
            -hostname  => $this->{_ip},
            -version   => $this->{_SNMPVersion},
            -timeout   => 2,
            -retries   => 1,
            -community => $this->{_SNMPCommunityRead}
        );
    }
    if ( !defined( $this->{_sessionRead} ) ) {
        $logger->error( "error creating SNMP v"
                . $this->{_SNMPVersion}
                . " read connection to "
                . $this->{_ip} . ": "
                . $this->{_error} );
        return 0;
    } else {
        my $oid_sysLocation = '1.3.6.1.2.1.1.6.0';
        $logger->trace("SNMP get_request for sysLocation: $oid_sysLocation");
        my $result = $this->{_sessionRead}
            ->get_request( -varbindlist => [$oid_sysLocation] );
        if ( !defined($result) ) {
            $logger->error( "error creating SNMP v"
                    . $this->{_SNMPVersion}
                    . " read connection to "
                    . $this->{_ip} . ": "
                    . $this->{_sessionRead}->error() );
            $this->{_sessionRead} = undef;
            return 0;
        }
    }
    return 1;
}

=item disconnectRead - closing read connection to switch

=cut

sub disconnectRead {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !defined( $this->{_sessionRead} ) ) {
        return 1;
    }
    $logger->debug( "closing SNMP v"
            . $this->{_SNMPVersion}
            . " read connection to $this->{_ip}" );
    $this->{_sessionRead}->close;
    return 1;
}

=item connectWrite - establish write connection to switch

=cut

sub connectWrite {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( defined( $this->{_sessionWrite} ) ) {
        return 1;
    }
    $logger->debug( "opening SNMP v"
            . $this->{_SNMPVersion}
            . " write connection to $this->{_ip}" );
    if ( $this->{_SNMPVersion} eq '3' ) {
        ( $this->{_sessionWrite}, $this->{_error} ) = Net::SNMP->session(
            -hostname     => $this->{_ip},
            -version      => $this->{_SNMPVersion},
            -timeout      => 2,
            -retries      => 1,
            -username     => $this->{_SNMPUserNameWrite},
            -authprotocol => $this->{_SNMPAuthProtocolWrite},
            -authpassword => $this->{_SNMPAuthPasswordWrite},
            -privprotocol => $this->{_SNMPPrivProtocolWrite},
            -privpassword => $this->{_SNMPPrivPasswordWrite}
        );
    } else {
        ( $this->{_sessionWrite}, $this->{_error} ) = Net::SNMP->session(
            -hostname  => $this->{_ip},
            -version   => $this->{_SNMPVersion},
            -timeout   => 2,
            -retries   => 1,
            -community => $this->{_SNMPCommunityWrite}
        );
    }
    if ( !defined( $this->{_sessionWrite} ) ) {
        $logger->error( "error creating SNMP v"
                . $this->{_SNMPVersion}
                . " write connection to "
                . $this->{_ip} . ": "
                . $this->{_error} );
        return 0;
    } else {
        my $oid_sysLocation = '1.3.6.1.2.1.1.6.0';
        $logger->trace("SNMP get_request for sysLocation: $oid_sysLocation");
        my $result = $this->{_sessionWrite}
            ->get_request( -varbindlist => [$oid_sysLocation] );
        if ( !defined($result) ) {
            $logger->error( "error creating SNMP v"
                    . $this->{_SNMPVersion}
                    . " write connection to "
                    . $this->{_ip} . ": "
                    . $this->{_sessionWrite}->error() );
            $this->{_sessionWrite} = undef;
            return 0;
        } else {
            my $sysLocation = $result->{$oid_sysLocation} || '';
            $logger->trace(
                "SNMP set_request for sysLocation: $oid_sysLocation to $sysLocation"
            );
            $result = $this->{_sessionWrite}->set_request(
                -varbindlist => [
                    "$oid_sysLocation", Net::SNMP::OCTET_STRING,
                    $sysLocation
                ]
            );
            if ( !defined($result) ) {
                $logger->error( "error creating SNMP v"
                        . $this->{_SNMPVersion}
                        . " write connection to "
                        . $this->{_ip} . ": "
                        . $this->{_sessionWrite}->error()
                        . " it looks like you specified a read-only community instead of a read-write one"
                );
                $this->{_sessionWrite} = undef;
                return 0;
            }
        }
    }
    return 1;
}

=item disconnectWrite - closing write connection to switch

=cut

sub disconnectWrite {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !defined( $this->{_sessionWrite} ) ) {
        return 1;
    }
    $logger->debug( "closing SNMP v"
            . $this->{_SNMPVersion}
            . " write connection to $this->{_ip}" );
    $this->{_sessionWrite}->close;
    return 1;
}

=item connectMySQL - create MySQL database connection

=cut

sub connectMySQL {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->debug("initializing database connection");
    if ( defined( $this->{_mysqlConnection} ) ) {
        $logger->debug("database connection already exists - reusing it");
        return 1;
    }
    $logger->debug( "connecting to database server "
            . $this->{_dbHostname}
            . " as user "
            . $this->{_dbUser}
            . "; database name is "
            . $this->{_dbName} );
    $this->{_mysqlConnection}
        = DBI->connect( "dbi:mysql:dbname="
            . $this->{_dbName}
            . ";host="
            . $this->{_dbHostname},
        $this->{_dbUser}, $this->{_dbPassword}, { PrintError => 0 } );
    if ( !defined( $this->{_mysqlConnection} ) ) {
        $logger->error(
            "couldn't connection to MySQL server: " . DBI->errstr );
        return 0;
    }
    locationlog_db_prepare( $this->{_mysqlConnection} );
    node_db_prepare( $this->{_mysqlConnection} );
    return 1;
}

=item setVlan - set port VLAN

=cut

sub setVlan {
    my ($this, $ifIndex, $newVlan, $switch_locker_ref, $presentPCMac) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->warn(
            "Should set ifIndex $ifIndex to VLAN $newVlan but the switch is not in production -> Do nothing"
        );
        return 1;
    }

    my $vlan = $this->getVlan($ifIndex);

    if ( !defined($presentPCMac)
        && ( $newVlan ne $this->{_macDetectionVlan} ) )
    {
        my @macArray = $this->_getMacAtIfIndex( $ifIndex, $vlan );
        if ( scalar(@macArray) == 1 ) {
            $presentPCMac = $macArray[0];
        }
    }

    #handle some exceptions
    if ( grep( { $_ == $newVlan } @{ $this->{_vlans} } ) == 0 )
    {    #unmanaged VLAN ?
        $logger->warn(
            "new VLAN $newVlan is not a managed VLAN -> replacing VLAN $newVlan with MAC detection VLAN "
                . $this->{_macDetectionVlan} );
        $newVlan = $this->{_macDetectionVlan};
    }

    #closes old locationlog entries and create a new one if required
    locationlog_synchronize($this->{_ip}, $ifIndex, $newVlan, $presentPCMac, NO_VOIP, WIRED_SNMP_TRAPS);

    if ( !$this->isDefinedVlan($newVlan) ) {    #new VLAN is not defined
        if ( $newVlan == $this->{_macDetectionVlan} ) {
            $logger->warn( "MAC detection VLAN "
                    . $this->{_macDetectionVlan}
                    . " is not defined on switch "
                    . $this->{_ip}
                    . " -> Do nothing" );
            return 1;
        }
        $logger->warn( "new VLAN $newVlan is not defined on switch "
                . $this->{_ip}
                . " -> replacing VLAN $newVlan with MAC detection VLAN "
                . $this->{_macDetectionVlan} );
        $newVlan = $this->{_macDetectionVlan};
        if ( !$this->isDefinedVlan($newVlan) ) {
            $logger->warn( "MAC detection VLAN "
                    . $this->{_macDetectionVlan}
                    . " is also not defined on switch "
                    . $this->{_ip}
                    . " -> Do nothing" );
            return 1;
        }
    }

    if ( grep( { $_ == $vlan } @{ $this->{_vlans} } ) == 0 )
    {    #unmanaged VLAN ?
        $logger->warn("old VLAN $vlan is not a managed VLAN -> Do nothing");
        return 1;
    }

    if ( $vlan == $newVlan ) {
        $logger->info( "Should set "
                . $this->{_ip}
                . " ifIndex $ifIndex to VLAN $newVlan but it is already in this VLAN -> Do nothing"
        );

        return 1;
    }

    # so far so good, you can get rid of the below lines after I did a lot of tests
    #update locationlog
    # - not sure this is useful after locationlog_synchronize
    # - test with it disabled
    #$logger->debug("updating locationlog for " . $this->{_ip} . " ifIndex $ifIndex" );
    #if ($closeAllOpenLocationlogEntries) {
    #    locationlog_update_end( $this->{_ip}, $ifIndex, $presentPCMac );
    #} else {
    #    locationlog_update_end_switchport_no_VoIP( $this->{_ip}, $ifIndex );
    #}
    #locationlog_insert_start($this->{_ip}, $ifIndex, $newVlan, $presentPCMac, NO_VOIP, WIRED_SNMP_TRAPS);

    #and finally set the VLAN
    $logger->info( "setting VLAN at "
            . $this->{_ip}
            . " ifIndex $ifIndex from $vlan to $newVlan" );
    return $this->_setVlan( $ifIndex, $newVlan, $vlan, $switch_locker_ref );
}

=item setVlanWithName - set the ifIndex VLAN to the VLAN name in the switch instead of vlan number

TODO: not implemented, currently only a nameholder

=cut
sub setVlanWithName {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->warn("not implemented!");
    return;
}

=item _setVlanByOnlyModifyingPvid

=cut

sub _setVlanByOnlyModifyingPvid {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';    # Q-BRIDGE-MIB
    my $result;

    if ( !$this->connectWrite() ) {
        return 0;
    }

    my $dot1dBasePort = $this->getDot1dBasePortForThisIfIndex($ifIndex);

    $logger->trace("SNMP set_request for Pvid for new VLAN");
    $result
        = $this->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_dot1qPvid.$dot1dBasePort", Net::SNMP::GAUGE32, $newVlan ]
        );
    if ( !defined($result) ) {
        $logger->error(
            "error setting Pvid: " . $this->{_sessionWrite}->error );
    }
    return ( defined($result) );
}

=item setVlanByName - set the ifIndex VLAN to the VLAN identified by given name in switches.conf

Input: ifIndex, vlan name (as in switches.conf), switch lock

=cut
# TODO: get rid of the _ character in front of the vlan variables (refactoring)
sub setVlanByName {
    my ($this, $ifIndex, $vlanName, $switch_locker_ref) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    if (!exists($this->{"_".$vlanName})) {
        # VLAN name doesn't exist
        $logger->warn("VLAN $vlanName is not a valid VLAN identifier (see switches.conf)");
        return;
    }

    if ($this->{"_".$vlanName} !~ /^\d+$/) {
        # is not resolved to a valid VLAN number
        $logger->warn("VLAN $vlanName is not properly configured in switches.conf, not a vlan number");
        return;
    }
    return $this->setVlan($ifIndex, $this->{"_".$vlanName}, $switch_locker_ref);
}

=item setIsolationVlan - set the port VLAN to the isolation VLAN

DEPRECATED: use setVlanByName($ifIndex, $switch_locker_ref, 'isolationVlan') instead 

=cut
# TODO deprecated in 1.8.7 remove for 1.9 / 2.0 ?
sub setIsolationVlan {
    my ( $this, $ifIndex, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->warn("this method is deprecated, please update your code to use setVlanByName instead");
    return $this->setVlan( $ifIndex, $this->{_isolationVlan},
        $switch_locker_ref );
}

=item setRegistrationVlan - set the port VLAN to the registration VLAN

DEPRECATED: use setVlanByName($ifIndex, $switch_locker_ref, 'registrationVlan') instead 

=cut
# TODO deprecated in 1.8.7 remove for 1.9 / 2.0 ?
sub setRegistrationVlan {
    my ( $this, $ifIndex, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->warn("this method is deprecated, please update your code to use setVlanByName instead");
    return $this->setVlan( $ifIndex, $this->{_registrationVlan},
        $switch_locker_ref );
}

=item getIfOperStatus - obtain the ifOperStatus of the specified switch port (1 indicated up, 2 indicates down)

=cut

sub getIfOperStatus {
    my ( $this, $ifIndex ) = @_;
    my $logger           = Log::Log4perl::get_logger( ref($this) );
    my $oid_ifOperStatus = '1.3.6.1.2.1.2.2.1.8';
    if ( !$this->connectRead() ) {
        return 0;
    }
    $logger->trace(
        "SNMP get_request for ifOperStatus: $oid_ifOperStatus.$ifIndex");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$oid_ifOperStatus.$ifIndex"] );
    return $result->{"$oid_ifOperStatus.$ifIndex"};
}

=item setMacDetectionVlan - set the port VLAN to the MAC detection VLAN

=cut 

sub setMacDetectionVlan {
    my ( $this, $ifIndex, $switch_locker_ref,
        $closeAllOpenLocationlogEntries )
        = @_;
    return $this->setVlan( $ifIndex, $this->{_macDetectionVlan},
        $switch_locker_ref, undef, $closeAllOpenLocationlogEntries );
}

=item setNormalVlan - set the port VLAN to the 'normal' VLAN

DEPRECATED: use setVlanByName($ifIndex, $switch_locker_ref, 'normalVlan') instead

=cut
# TODO deprecated in 1.8.7 remove for 1.9 / 2.0 ?
sub setNormalVlan {
    my ( $this, $ifIndex, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));
    $logger->warn("this method is deprecated, please update your code to use setVlanByName instead");
    return $this->setVlan( $ifIndex, $this->{_normalVlan},
        $switch_locker_ref );
}

=item getAlias - get the port description

=cut

sub getAlias {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    my $OID_ifAlias = '1.3.6.1.2.1.31.1.1.1.18';
    $logger->trace("SNMP get_request for ifAlias: $OID_ifAlias.$ifIndex");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_ifAlias.$ifIndex"] );
    return $result->{"$OID_ifAlias.$ifIndex"};
}

=item getSwitchLocation - get the switch location string

=cut

sub getSwitchLocation {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    my $OID_sysLocation = '1.3.6.1.2.1.1.6.0';
    $logger->trace("SNMP get_request for sysLocation: $OID_sysLocation");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_sysLocation"] );
    return $result->{"$OID_sysLocation"};
}
        

=item setAlias - set the port description

=cut

sub setAlias {
    my ( $this, $ifIndex, $alias ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->info( "setting "
            . $this->{_ip}
            . " ifIndex $ifIndex ifAlias from "
            . $this->getAlias($ifIndex)
            . " to $alias" );
    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't change this port ifAlias");
        return 1;
    }
    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $OID_ifAlias = '1.3.6.1.2.1.31.1.1.1.18';
    $logger->trace(
        "SNMP set_request for ifAlias: $OID_ifAlias.$ifIndex = $alias");
    my $result = $this->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_ifAlias.$ifIndex", Net::SNMP::OCTET_STRING, $alias ] );
    return ( defined($result) );
}

=item getManagedIfIndexes - get the list of ifIndexes which are managed

=cut

sub getManagedIfIndexes {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my @managedIfIndexes;
    my @tmp_managedIfIndexes;
    my $ifTypeHashRef;
    my $ifOperStatusHashRef;
    my $vlanHashRef;
    my $OID_ifType       = '1.3.6.1.2.1.2.2.1.3';
    my $OID_ifOperStatus = '1.3.6.1.2.1.2.2.1.8';

    my @UpLinks = $this->getUpLinks();    # fetch the UpLink list
    if ( !$this->connectRead() ) {
        return @managedIfIndexes;
    }

    # fetch all ifType at once
    $logger->trace("SNMP get_request for ifType: $OID_ifType");
    my $result = $this->{_sessionRead}->get_table( -baseoid => $OID_ifType );
    foreach my $key ( keys %{$result} ) {
        $key =~ /^$OID_ifType\.(\d+)$/;
        $ifTypeHashRef->{$1} = $result->{$key};
    }

    # fetch all ifOperStatus at once
    $logger->trace("SNMP get_request for ifOperStatus: $OID_ifOperStatus");
    $result
        = $this->{_sessionRead}->get_table( -baseoid => $OID_ifOperStatus );
    foreach my $key ( keys %{$result} ) {
        $key =~ /^$OID_ifOperStatus\.(\d+)$/;
        $ifOperStatusHashRef->{$1} = $result->{$key};
    }

    foreach my $ifIndex ( keys %{$ifTypeHashRef} ) {

        # skip non ethernetCsmacd port type
        if ( $ifTypeHashRef->{$ifIndex} == 6 ) {

            # skip UpLinks
            if ( grep( { $_ == $ifIndex } @UpLinks ) == 0 ) {
                my $ifOperStatus = $ifOperStatusHashRef->{$ifIndex};

                # skip ports with ifOperStatus not present
                if (   ( defined $ifOperStatus )
                    && ( $ifOperStatusHashRef->{$ifIndex} != 6 ) )
                {
                    push @tmp_managedIfIndexes, $ifIndex;
                } else {
                    $logger->debug(
                        "ifIndex $ifIndex excluded from managed ifIndexes since its ifOperstatus is 6 (notPresent)"
                    );
                }
            } else {
                $logger->debug(
                    "ifIndex $ifIndex excluded from managed ifIndexes since it's an uplink"
                );
            }
        } else {
            $logger->debug(
                "ifIndex $ifIndex excluded from managed ifIndexes since it's not an ethernetCsmacd port"
            );
        }
    }

    $vlanHashRef = $this->getAllVlans(@tmp_managedIfIndexes);
    foreach my $ifIndex (@tmp_managedIfIndexes) {
        my $portVlan = $vlanHashRef->{$ifIndex};
        if ( defined $portVlan ) {    # skip port with no VLAN

            if ( grep( { $_ == $portVlan } @{ $this->{_vlans} } ) != 0 )
            {                         # skip port in a non-managed VLAN
                push @managedIfIndexes, $ifIndex;
            } else {
                $logger->debug(
                    "ifIndex $ifIndex excluded from managed ifIndexes since it's not in a managed VLAN"
                );
            }
        } else {
            $logger->debug(
                "ifIndex $ifIndex excluded from managed ifIndexes since no VLAN could be determined"
            );
        }
    }
    return @managedIfIndexes;
}

=item getMode - get the mode

=cut

sub getMode {
    my ($this) = @_;
    return $this->{_mode};
}

=item isTestingMode - return True if $switch-E<gt>{_mode} eq 'testing'

=cut

sub isTestingMode {
    my ($this) = @_;
    return ( $this->getMode() eq 'testing' );
}

=item isIgnoreMode - return True if $switch-E<gt>{_mode} eq 'ignore'

=cut

sub isIgnoreMode {
    my ($this) = @_;
    return ( $this->getMode() eq 'ignore' );
}

=item isRegistrationMode - return True if $switch-E<gt>{_mode} eq 'registration'

=cut

sub isRegistrationMode {
    my ($this) = @_;
    return ( $this->getMode() eq 'registration' );
}

=item isProductionMode - return True if $switch-E<gt>{_mode} eq 'production'

=cut

sub isProductionMode {
    my ($this) = @_;
    return ( $this->getMode() eq 'production' );
}

=item isDiscoveryMode - return True if $switch-E<gt>{_mode} eq 'discory'

=cut

sub isDiscoveryMode {
    my ($this) = @_;
    return ( $this->getMode() eq 'discovery' );
}

=item isVoIPEnabled - return true if $switch-E<gt>{_VoIPEnabled} == 1

=cut

sub isVoIPEnabled {
    my ($this) = @_;
    return 0;
}

=item setVlanAllPort - set the port VLAN for all the non-UpLink ports of a switch

=cut

sub setVlanAllPort {
    my ( $this, $vlan, $switch_locker_ref ) = @_;
    my $oid_ifType = '1.3.6.1.2.1.2.2.1.3';    # MIB: ifTypes
    my @ports;
    my @UpLinks = $this->getUpLinks();         # fetch the UpLink list

    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->info("setting all ports of switch $this->{_ip} to VLAN $vlan");
    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't change any port VLAN");
        return 1;
    }

    if ( !$this->connectRead() ) {
        return 0;
    }

    my @managedIfIndexes = $this->getManagedIfIndexes();
    foreach my $ifIndex (@managedIfIndexes) {
        $logger->debug(
            "setting " . $this->{_ip} . " ifIndex $ifIndex to VLAN $vlan" );
        if ($vlan =~ /^\d+$/) {
            # if vlan is an integer, then assume its a vlan number
            $this->setVlan( $ifIndex, $vlan, $switch_locker_ref );
        } else {
            # otherwise its a vlan name
            $this->setVlanByName($ifIndex, $vlan, $switch_locker_ref);
        }
    }
}

=item resetVlanAllPort - reset the port VLAN for all the non-UpLink ports of a switch

=cut

sub resetVlanAllPort {
    my ( $this, $switch_locker_ref ) = @_;
    my $oid_ifType = '1.3.6.1.2.1.2.2.1.3';    # MIB: ifTypes
    my @UpLinks    = $this->getUpLinks();      # fetch the UpLink list

    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->info("resetting all ports of switch $this->{_ip}");
    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change any port");
        return 1;
    }

    if ( !$this->connectRead() ) {
        return 0;
    }

    my @managedIfIndexes = $this->getManagedIfIndexes();
    foreach my $ifIndex (@managedIfIndexes) {
        if ( $this->isPortSecurityEnabled($ifIndex) )
        {    # disabling port-security
            $logger->debug(
                "disabling port-security on ifIndex $ifIndex before resetting to vlan "
                    . $this->{_normalVlan} );
            $this->setPortSecurityDisabled($ifIndex);
        }
        $logger->debug( "setting "
                . $this->{_ip}
                . " ifIndex $ifIndex to VLAN "
                . $this->{_normalVlan} );
        $this->setVlan( $ifIndex, $this->{_normalVlan}, $switch_locker_ref );
    }
}

=item getMacAtIfIndex - obtain list of MACs at switch ifIndex

=cut

sub getMacAtIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $i      = 0;
    my $start  = time;
    my @macArray;

    # we try to get the MAC 30 times or for 2 minutes whichever comes first
    do {
        sleep(2) unless ( $i == 0 );
        $logger->debug( "attempt "
                . ( $i + 1 )
                . " to obtain mac at "
                . $this->{_ip}
                . " ifIndex $ifIndex" );
        @macArray = $this->_getMacAtIfIndex($ifIndex);
        $i++;
    } while (($i < 30) && ((time-$start) < 120) && (scalar(@macArray) == 0));

    if (scalar(@macArray) == 0) {
        if ($i >= 30) {
            $logger->warn("Tried to grab MAC address at ifIndex $ifIndex "
                ."on switch ".$this->{_ip}." 30 times and failed");
        } else {
            $logger->warn("Tried to grab MAC address at ifIndex $ifIndex "
                ."on switch ".$this->{_ip}." for 2 minutes and failed");
        }
    }
    return @macArray;
}

=item getIfDesc - return ifDesc given ifIndex

=cut

sub getIfDesc {
    my ( $this, $ifIndex ) = @_;
    my $logger     = Log::Log4perl::get_logger( ref($this) );
    my $OID_ifDesc = '1.3.6.1.2.1.2.2.1.2';                     # IF-MIB
    my $oid        = $OID_ifDesc . "." . $ifIndex;
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for ifDesc: $oid");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$oid] );
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
    my ( $this, $ifIndex ) = @_;
    my $logger     = Log::Log4perl::get_logger( ref($this) );
    my $OID_ifName = '1.3.6.1.2.1.31.1.1.1.1';                  # IF-MIB
    my $oid        = $OID_ifName . "." . $ifIndex;
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for ifName: $oid");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$oid] );
    if ( exists( $result->{$oid} )
        && ( $result->{$oid} ne 'noSuchInstance' ) )
    {
        return $result->{$oid};
    }
    return '';
}

=item getIfNameIfIndexHash - return ifName =E<gt> ifIndex hash

=cut

sub getIfNameIfIndexHash {
    my ($this)     = @_;
    my $logger     = Log::Log4perl::get_logger( ref($this) );
    my $OID_ifName = '1.3.6.1.2.1.31.1.1.1.1';                  # IF-MIB
    my %ifNameIfIndexHash;
    if ( !$this->connectRead() ) {
        return %ifNameIfIndexHash;
    }
    $logger->trace("SNMP get_request for ifName: $OID_ifName");
    my $result = $this->{_sessionRead}->get_table( -baseoid => $OID_ifName );
    foreach my $key ( keys %{$result} ) {
        $key =~ /^$OID_ifName\.(\d+)$/;
        $ifNameIfIndexHash{ $result->{$key} } = $1;
    }
    return %ifNameIfIndexHash;
}

=item setAdminStatus - shutdown or enable port

=cut

sub setAdminStatus {
    my ( $this, $ifIndex, $enabled ) = @_;
    my $logger            = Log::Log4perl::get_logger( ref($this) );
    my $OID_ifAdminStatus = '1.3.6.1.2.1.2.2.1.7';
    if ( !$this->connectWrite() ) {
        return 0;
    }
    $logger->trace(
        "SNMP set_request for ifAdminStatus: $OID_ifAdminStatus.$ifIndex = "
            . ( $enabled ? 1 : 2 ) );
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_ifAdminStatus.$ifIndex", Net::SNMP::INTEGER,
            ( $enabled ? 1 : 2 ),
        ]
    );
    return ( defined($result) );
}

sub isLearntTrapsEnabled {
    my ( $this, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub isRemovedTrapsEnabled {
    my ( $this, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub isPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub setPortSecurityDisabled {
    my ( $this, $ifIndex, $trueFalse ) = @_;
    return ( 0 == 1 );
}

sub isDynamicPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub isStaticPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub getPhonesDPAtIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my @phones;
    if ( !$this->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch " . $this->{_ip} );
        return @phones;
    }
    return @phones;
}

sub hasPhoneAtIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch " . $this->{_ip} );
        return 0;
    }
    my @macArray
        = $this->_getMacAtIfIndex( $ifIndex, $this->getVoiceVlan($ifIndex) );
    foreach my $mac (@macArray) {
        if ( !$this->isFakeMac($mac) ) {
            $logger->trace("determining if node $mac is VoIP");
            my $node_info = node_view_with_fingerprint($mac);

            # is node voip or does it have a phone dhcp fingerprint?
            if ( defined($node_info)
                && ( ($node_info->{dhcp_fingerprint} =~ /VoIP Phone/)||($node_info->{voip} eq 'yes')) )
            {
                return 1;
            }
        }
    }
    $logger->trace( "determining through discovery protocols if "
            . $this->{_ip}
            . " ifIndex $ifIndex has VoIP phone connected" );
    return ( scalar( $this->getPhonesDPAtIfIndex($ifIndex) ) > 0 );
}

sub isPhoneAtIfIndex {
    my ( $this, $mac, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch " . $this->{_ip} );
        return 0;
    }
    if ( $this->isFakeVoIPMac($mac) ) {
        $logger->debug("MAC $mac is fake VoIP MAC");
        return 1;
    }
    if ( $this->isFakeMac($mac) ) {
        $logger->debug("MAC $mac is fake MAC");
        return 0;
    }
    $logger->trace("determining DHCP fingerprint info for $mac");
    my $node_info = node_view_with_fingerprint($mac);

    #do we have node information
    if (defined($node_info)) {
        if ($node_info->{voip} eq 'yes') {
            $logger->debug("This is a VoIP phone according to node.voip");
            return 1;
        }

        if ( $node_info->{dhcp_fingerprint} =~ /VoIP Phone/ ) {
            $logger->debug("DHCP fingerprint for $mac indicates VoIP phone");
            return 1;
        }

        #unknown DHCP fingerprint or no DHCP fingerprint
        if ( $node_info->{dhcp_fingerprint} ne ' ' ) {
            $logger->debug( "DHCP fingerprint for $mac indicates "
                    . $node_info->{dhcp_fingerprint}
                    . ". This is not a VoIP phone" );
            return 0;
        }
    }
    if (defined($ifIndex)) {
        $logger->debug("determining if $mac is VoIP phone through discovery protocols");
        my @phones = $this->getPhonesDPAtIfIndex($ifIndex);
        return ( grep( { lc($_) eq lc($mac) } @phones ) != 0 );
    } else {
        return 0;
    }
}

sub getMinOSVersion {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return -1;
}

sub getMaxMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return -1;
}

sub getSecureMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $secureMacAddrHashRef = {};
    my $logger               = Log::Log4perl::get_logger( ref($this) );
    return $secureMacAddrHashRef;
}

sub getAllSecureMacAddresses {
    my ($this)               = @_;
    my $logger               = Log::Log4perl::get_logger( ref($this) );
    my $secureMacAddrHashRef = {};
    return $secureMacAddrHashRef;
}

sub authorizeMAC {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return 1;
}

sub _authorizeMAC {
    my ( $this, $ifIndex, $mac, $authorize, $vlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return 1;
}

=item getRegExpFromList - analyze a list and determine a regexp pattern from this list (used for show mac-address-table)

=cut

sub getRegExpFromList {
    my ( $this, @list ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my %decompHash;
    foreach my $item (@list) {
        $item =~ /^(.+\/)(\d+)$/;
        if ( $2 < 10 ) {
            push @{ $decompHash{$1}{0} }, $2;
        } else {
            push @{ $decompHash{$1}{ substr( $2, 0, length($2) - 1 ) } },
                substr( $2, length($2) - 1 );
        }
    }

    my $regexp         = '(';
    my @portDescStarts = sort keys %decompHash;
    for ( my $i = 0; $i < scalar(@portDescStarts); $i++ ) {
        if ( $i > 0 ) {
            $regexp .= '|';
        }
        $regexp .= "($portDescStarts[$i](";
        my @portNbStarts = sort keys %{ $decompHash{ $portDescStarts[$i] } };
        for ( my $j = 0; $j < scalar(@portNbStarts); $j++ ) {
            if ( $j > 0 ) {
                $regexp .= '|';
            }
            if ( $portNbStarts[$j] == 0 ) {
                $regexp .= "["
                    . join(
                    '',
                    sort( @{$decompHash{ $portDescStarts[$i] }
                                { $portNbStarts[$j] }
                            } )
                    ) . "]";
            } else {
                $regexp 
                    .= '(' 
                    . $portNbStarts[$j] . "["
                    . join(
                    '',
                    sort( @{$decompHash{ $portDescStarts[$i] }
                                { $portNbStarts[$j] }
                            } )
                    ) . "])";
            }
        }
        $regexp .= '))';
    }
    $regexp .= ')[^0-9]*$';
    return $regexp;
}

=item getBitAtPosition - returns the bit at the position specified

The input must be the untranslated raw result of an snmp get_table

=cut
sub getBitAtPosition {
   my ($this, $bitStream, $position) = @_;
   return substr(unpack('B*', $bitStream), $position, 1);
}

=item modifyBitmask - replaces the specified bit in a packed bitmask and returns the modified bitmask, re-packed

=cut

sub modifyBitmask {
    my ( $this, $bitMask, $offset, $replacement ) = @_;
    my $bitMaskString = unpack( 'B*', $bitMask );
    substr( $bitMaskString, $offset, 1, $replacement );
    return pack( 'B*', $bitMaskString );
}

=item createPortListWithOneItem - generate a PortList (Bitmask) with one bit turned on at the specified index value

The output is a packed binary representation useful to snmp::set_request

=cut

sub createPortListWithOneItem {
    my ($this, $position) = @_;
    
    # output zeros up to position -1 and put a 1 in position
    my $numZeros = $position - 1;
    return pack("B*",0 x $numZeros . 1);
}

=item reverseBitmask - reverses all the bits (0 to 1, 1 to 0) from a packed bitmask and returns this new bitmask re-packed

Works on byte blocks since perl's bitewise not operates at the arithmetic level and some hardware have so many ports that I could overflow integers.

=cut

sub reverseBitmask {
    my ($this, $bitMask) = @_;

    # reverse byte chunks since we don't know if input will be an int too large
    my $flippedBitMask = "";
    for (my $i = 0; $i < length($bitMask); $i++) {

       # chop string; convert string to byte; bitewise not (arithmetic); convert number to byte (& 255 avoids a warning)
       $flippedBitMask .= pack("C", ~ unpack("C", substr($bitMask,$i,$i+1)) & 255);
    }

    return $flippedBitMask;
}

=item getSysUptime - returns the sysUpTime

=cut

sub getSysUptime {
    my ($this)        = @_;
    my $logger        = Log::Log4perl::get_logger( ref($this) );
    my $oid_sysUptime = '1.3.6.1.2.1.1.3.0';
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysUptime: $oid_sysUptime");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => [$oid_sysUptime] );
    return $result->{$oid_sysUptime};
}

=item getIfType - return the ifType

=cut

sub getIfType {
    my ( $this, $ifIndex ) = @_;
    my $logger     = Log::Log4perl::get_logger( ref($this) );
    my $OID_ifType = '1.3.6.1.2.1.2.2.1.3';                     #IF-MIB
    if ( !$this->connectRead() ) {
        return 0;
    }
    $logger->trace("SNMP get_request for ifType: $OID_ifType.$ifIndex");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_ifType.$ifIndex"] );
    return $result->{"$OID_ifType.$ifIndex"};
}

=item _getMacAtIfIndex - returns the list of MACs

=cut

sub _getMacAtIfIndex {
    my ( $this, $ifIndex, $vlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my @macArray;
    if ( !$this->connectRead() ) {
        return @macArray;
    }
    if ( !defined($vlan) ) {
        $vlan = $this->getVlan($ifIndex);
    }
    my %macBridgePortHash = $this->getMacBridgePortHash($vlan);
    foreach my $_mac ( keys %macBridgePortHash ) {
        if ( $macBridgePortHash{$_mac} eq $ifIndex ) {
            push @macArray, $_mac;
        }
    }
    if (!@macArray) {
        $logger->warn("couldn't get MAC at ifIndex $ifIndex. This is a problem.");
    }
    return @macArray;
}

sub getAllDot1dBasePorts {
    my ( $this, @ifIndexes ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !@ifIndexes ) {
        @ifIndexes = $this->getManagedIfIndexes();
    }
    my $dot1dBasePortHashRef;
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB
    if ( !$this->connectRead() ) {
        return $dot1dBasePortHashRef;
    }
    $logger->trace(
        "SNMP get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex");
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => $OID_dot1dBasePortIfIndex );
    my $dot1dBasePort = undef;
    foreach my $key ( keys %{$result} ) {
        my $ifIndex = $result->{$key};
        if ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) {
            $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
            $dot1dBasePort = $1;
            $logger->debug(
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
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB
    my $dot1dBasePort            = undef;
    if ( !$this->connectRead() ) {
        return $dot1dBasePort;
    }
    $logger->trace(
        "SNMP get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex");
    my $result = $this->{_sessionRead}
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

sub getAllIfDesc {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $ifDescHashRef;
    my $OID_ifDesc = '1.3.6.1.2.1.2.2.1.2';    # IF-MIB

    if ( !$this->connectRead() ) {
        return $ifDescHashRef;
    }

    $logger->trace("SNMP get_table for ifDesc: $OID_ifDesc");
    my $result = $this->{_sessionRead}->get_table( -baseoid => $OID_ifDesc );
    foreach my $key ( keys %{$result} ) {
        my $ifDesc = $result->{$key};
        $key =~ /^$OID_ifDesc\.(\d+)$/;
        my $ifIndex = $1;
        $ifDescHashRef->{$ifIndex} = $ifDesc;
    }
    return $ifDescHashRef;
}

sub getAllIfType {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $ifTypeHashRef;
    my $OID_ifType = '1.3.6.1.2.1.2.2.1.3';

    if ( !$this->connectRead() ) {
        return $ifTypeHashRef;
    }

    $logger->trace("SNMP get_table for ifType: $OID_ifType");
    my $result = $this->{_sessionRead}->get_table( -baseoid => $OID_ifType );
    foreach my $key ( keys %{$result} ) {
        my $ifType = $result->{$key};
        $key =~ /^$OID_ifType\.(\d+)$/;
        my $ifIndex = $1;
        $ifTypeHashRef->{$ifIndex} = $ifType;
    }
    return $ifTypeHashRef;
}

sub getAllVlans {
    my ( $this, @ifIndexes ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $vlanHashRef;
    if ( !@ifIndexes ) {
        @ifIndexes = $this->getManagedIfIndexes();
    }

    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';    # Q-BRIDGE-MIB
    if ( !$this->connectRead() ) {
        return $vlanHashRef;
    }
    my $dot1dBasePortHashRef = $this->getAllDot1dBasePorts(@ifIndexes);

    $logger->trace("SNMP get_request for dot1qPvid: $OID_dot1qPvid");
    my $result
        = $this->{_sessionRead}->get_table( -baseoid => $OID_dot1qPvid );
    foreach my $key ( keys %{$result} ) {
        my $vlan = $result->{$key};
        $key =~ /^$OID_dot1qPvid\.(\d+)$/;
        my $dot1dBasePort = $1;
        if ( defined( $dot1dBasePortHashRef->{$dot1dBasePort} ) ) {
            $vlanHashRef->{ $dot1dBasePortHashRef->{$dot1dBasePort} } = $vlan;
        }
    }
    return $vlanHashRef;
}

=item getVoiceVlan - returns the port voice VLAN ID

=cut

sub getVoiceVlan {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( $this->isVoIPEnabled() ) {
        $logger->error("function is NOT implemented");
        return -1;
    }
    return -1;
}

=item getVlan - returns the port PVID

=cut

sub getVlan {
    my ( $this, $ifIndex ) = @_;
    my $logger        = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1qPvid = '1.3.6.1.2.1.17.7.1.4.5.1.1';           # Q-BRIDGE-MIB
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $dot1dBasePort = $this->getDot1dBasePortForThisIfIndex($ifIndex);
    if ( !defined($dot1dBasePort) ) {
        return '';
    }

    $logger->trace(
        "SNMP get_request for dot1qPvid: $OID_dot1qPvid.$dot1dBasePort");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_dot1qPvid.$dot1dBasePort"] );
    return $result->{"$OID_dot1qPvid.$dot1dBasePort"};
}

=item getVlans - returns the VLAN ID - name mapping

=cut

sub getVlans {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1qVlanStaticName = '1.3.6.1.2.1.17.7.1.4.3.1.1';  #Q-BRIDGE-MIB
    my $vlans                   = {};
    if ( !$this->connectRead() ) {
        return $vlans;
    }

    $logger->trace(
        "SNMP get_table for dot1qVlanStaticName: $OID_dot1qVlanStaticName");
    my $result = $this->{_sessionRead}
        ->get_table( -baseoid => $OID_dot1qVlanStaticName );

    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            $key =~ /^$OID_dot1qVlanStaticName\.(\d+)$/;
            $vlans->{$1} = $result->{$key};
        }
    }

    return $vlans;
}

=item isDefinedVlan - determines if the VLAN is defined on the switch

=cut

sub isDefinedVlan {
    my ( $this, $vlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1qVlanStaticName = '1.3.6.1.2.1.17.7.1.4.3.1.1';  #Q-BRIDGE-MIB
    if ( !$this->connectRead() ) {
        return 0;
    }

    $logger->trace(
        "SNMP get_request for dot1qVlanStaticName: $OID_dot1qVlanStaticName.$vlan"
    );
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_dot1qVlanStaticName.$vlan"] );

    return (
               defined($result)
            && exists( $result->{"$OID_dot1qVlanStaticName.$vlan"} )
            && (
            $result->{"$OID_dot1qVlanStaticName.$vlan"} ne 'noSuchInstance' )
    );
}

sub getMacBridgePortHash {
    my $this   = shift;
    my $vlan   = shift || '';
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1qTpFdbPort = '1.3.6.1.2.1.17.7.1.2.2.1.2';    #Q-BRIDGE-MIB
    my %macBridgePortHash  = ();
    if ( !$this->connectRead() ) {
        return %macBridgePortHash;
    }
    $logger->trace("SNMP get_table for dot1qTpFdbPort: $OID_dot1qTpFdbPort");
    my $result;

    my $vlanFdbId = 0;
    if ( $vlan eq '' ) {
        $result = $this->{_sessionRead}
            ->get_table( -baseoid => $OID_dot1qTpFdbPort );
    } else {
        $vlanFdbId = $this->getVlanFdbId($vlan);
        $result    = $this->{_sessionRead}
            ->get_table( -baseoid => "$OID_dot1qTpFdbPort.$vlanFdbId" );
    }

    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            $key
                =~ /^$OID_dot1qTpFdbPort\.(\d+)\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
            if ( ( $vlanFdbId == 0 ) || ( $1 eq $vlanFdbId ) ) {
                my $mac = sprintf( "%02X:%02X:%02X:%02X:%02X:%02X",
                    $2, $3, $4, $5, $6, $7 );
                $macBridgePortHash{$mac} = $result->{$key};
            }
        }
    }
    return %macBridgePortHash;
}

sub getHubs {
    my $this              = shift;
    my $logger            = Log::Log4perl::get_logger( ref($this) );
    my @upLinks           = $this->getUpLinks();
    my $hubPorts          = {};
    my %macBridgePortHash = $this->getMacBridgePortHash();
    foreach my $mac ( keys %macBridgePortHash ) {
        my $ifIndex = $macBridgePortHash{$mac};
        if ( $ifIndex != 0 ) {

            # A value of '0' indicates that the port number has not
            # been learned but that the device does have some
            # forwarding/filtering information about this address
            # (e.g. in the dot1qStaticUnicastTable).
            if ( grep( { $_ == $ifIndex } @upLinks ) == 0 ) {

                # the port is not a upLink
                my $portVlan = $this->getVlan($ifIndex);
                if ( grep( { $_ == $portVlan } @{ $this->{_vlans} } ) != 0 ) {

                    # the port is in a VLAN we manage
                    push @{ $hubPorts->{$ifIndex} }, $mac;
                }
            }
        }
    }
    foreach my $ifIndex ( keys %$hubPorts ) {
        if ( scalar( @{ $hubPorts->{$ifIndex} } ) == 1 ) {
            delete( $hubPorts->{$ifIndex} );
        }
    }
    return $hubPorts;
}

sub getIfIndexForThisMac {
    my ( $this, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my @macParts = split( ':', $mac );
    if ( !$this->connectRead() ) {
        return -1;
    }
    foreach my $vlan ( @{ $this->{_vlans} } ) {
        my $oid
            = "1.3.6.1.2.1.17.7.1.2.2.1.2.$vlan."
            . hex( $macParts[0] ) . "."
            . hex( $macParts[1] ) . "."
            . hex( $macParts[2] ) . "."
            . hex( $macParts[3] ) . "."
            . hex( $macParts[4] ) . "."
            . hex( $macParts[5] );
        $logger->trace("SNMP get_request for $oid");
        my $result
            = $this->{_sessionRead}->get_request( -varbindlist => [$oid] );
        if ( ( defined($result) ) && ( !$this->isUpLink( $result->{$oid} ) ) )
        {
            return $result->{$oid};
        }
    }
    return -1;
}

sub getVmVlanType {
    my ( $this, $ifIndex ) = @_;
    return 1;
}

sub setVmVlanType {
    my ( $this, $ifIndex, $type ) = @_;
    return 1;
}

sub getMacAddrVlan {
    my $this    = shift;
    my @upLinks = $this->getUpLinks();
    my %ifIndexMac;
    my %macVlan;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $OID_dot1qTpFdbPort = '1.3.6.1.2.1.17.7.1.2.2.1.2';    #Q-BRIDGE-MIB
    if ( !$this->connectRead() ) {
        return %macVlan;
    }
    my $result
        = $this->{_sessionRead}->get_table( -baseoid => $OID_dot1qTpFdbPort );

    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            if ( grep( { $_ == $result->{$key} } @upLinks ) == 0 ) {
                my $portVlan = $this->getVlan( $result->{$key} );
                if ( grep( { $_ == $portVlan } @{ $this->{_vlans} } ) != 0 )
                {    # the port is in a VLAN we manage
                    push @{ $ifIndexMac{ $result->{$key} } }, $key;
                }
            }
        }
    }
    $logger->debug("List of MACS for every non-upLink ports (Dumper):");
    $logger->debug( Dumper(%ifIndexMac) );

    foreach my $ifIndex ( keys %ifIndexMac ) {
        my $macCount = scalar( @{ $ifIndexMac{$ifIndex} } );
        $logger->debug("port: $ifIndex; number of MACs: $macCount");
        if ( $macCount == 1 ) {
            $ifIndexMac{$ifIndex}[0]
                =~ /^$OID_dot1qTpFdbPort\.(\d+)\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
            my $mac = sprintf( "%02X:%02X:%02X:%02X:%02X:%02X",
                $2, $3, $4, $5, $6, $7 );
            $macVlan{$mac}{'vlan'}    = $1;
            $macVlan{$mac}{'ifIndex'} = $ifIndex;
        } elsif ( $macCount > 1 ) {
            $logger->warn(
                "ALERT: There is a hub on switch $this->{'_ip'} port $ifIndex. We found $macCount MACs on this port !"
            );
        }
    }
    $logger->debug("Show VLAN and port for every MACs (dumper):");
    $logger->debug( Dumper(%macVlan) );

    return %macVlan;
}

sub getAllMacs {
    my ( $this, @ifIndexes ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !@ifIndexes ) {
        @ifIndexes = $this->getManagedIfIndexes();
    }
    my $ifIndexVlanMacHashRef;

    my $OID_dot1qTpFdbPort = '1.3.6.1.2.1.17.7.1.2.2.1.2';    #Q-BRIDGE-MIB
    if ( !$this->connectRead() ) {
        return $ifIndexVlanMacHashRef;
    }
    my $result
        = $this->{_sessionRead}->get_table( -baseoid => $OID_dot1qTpFdbPort );

    my @vlansToConsider = @{ $this->{_vlans} };
    if ( $this->isVoIPEnabled() ) {
        if ( defined( $this->{_voiceVlan} ) ) {
            my $voiceVlan = $this->{_voiceVlan};
            if ( grep( { $_ == $voiceVlan } @vlansToConsider ) == 0 ) {
                push @vlansToConsider, $voiceVlan;
            }
        }
    }
    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            my $ifIndex = $result->{$key};
            if ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) {
                $key
                    =~ /^$OID_dot1qTpFdbPort\.(\d+)\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
                my $vlan = $1;
                if ( grep( { $_ == $vlan } @vlansToConsider ) > 0 ) {
                    my $mac = sprintf( "%02X:%02X:%02X:%02X:%02X:%02X",
                        $2, $3, $4, $5, $6, $7 );
                    push @{ $ifIndexVlanMacHashRef->{$ifIndex}->{$vlan} },
                        $mac;
                }
            }
        }
    }

    return $ifIndexVlanMacHashRef;
}

sub getAllIfOctets {
    my ( $this, @ifIndexes ) = @_;
    my $logger          = Log::Log4perl::get_logger( ref($this) );
    my $oid_ifInOctets  = '1.3.6.1.2.1.2.2.1.10';
    my $oid_ifOutOctets = '1.3.6.1.2.1.2.2.1.16';
    my $ifOctetsHashRef;
    if ( !$this->connectRead() ) {
        return $ifOctetsHashRef;
    }
    if ( !@ifIndexes ) {
        @ifIndexes = $this->getManagedIfIndexes();
    }

    $logger->trace("SNMP get_table for ifInOctets $oid_ifInOctets");
    my $result
        = $this->{_sessionRead}->get_table( -baseoid => $oid_ifInOctets );
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
    $logger->trace("SNMP get_table for ifOutOctets $oid_ifOutOctets");
    $result
        = $this->{_sessionRead}->get_table( -baseoid => $oid_ifOutOctets );
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

sub isNewerVersionThan {
    my ( $this, $versionToCompareToString ) = @_;
    my $currentVersion          = $this->getVersion();
    my @detectedOSVersionArray  = split( /\./, $currentVersion );
    my @versionToCompareToArray = split( /\./, $versionToCompareToString );
    my $i                       = 0;
    while ( $i < scalar(@detectedOSVersionArray) ) {
        if ( $detectedOSVersionArray[$i] > $versionToCompareToArray[$i] ) {
            return 1;
        }
        $i++;
    }
    return 0;
}

sub generateFakeMac {
    my ($this, $is_voice_vlan, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    # generating a fixed 6 digit string with ifIndex (zero filled)
    my $zero_filled_ifIndex = sprintf('%06d', $ifIndex);
    my $mac_suffix;
    if ($zero_filled_ifIndex !~ /^\d{6}$/) {
         $logger->warn("Unexpected ifIndex to generate a fake MAC for. "
             . "This could cause port-security problems. ifIndex: $zero_filled_ifIndex");
         $mac_suffix = "99:99:99";
    } else {
         $zero_filled_ifIndex =~ /(\d{2})(\d{2})(\d{2})/;
         $mac_suffix = "$1:$2:$3";
    }

    # VoIP will be different than non-VoIP
    return "02:00:" . ( ($is_voice_vlan) ? "01" : "00" ) . ":" . $mac_suffix;
}

sub isFakeMac {
    my ( $this, $mac ) = @_;
    return ( $mac =~ /^02:00:00/ );
}

sub isFakeVoIPMac {
    my ( $this, $mac ) = @_;
    return ( $mac =~ /^02:00:01/ );
}

sub getUpLinks {
    my ($this) = @_;
    my @upLinks;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( lc(@{ $this->{_uplink} }[0]) eq 'dynamic' ) {
        $logger->warn( "Warning: for switch "
                . $this->{_ip}
                . ", 'uplink = Dynamic' in config file but this is not supported !"
        );
        return -1;
    } else {
        @upLinks = @{ $this->{_uplink} };
    }
    return @upLinks;
}

sub getVlanFdbId {
    my ( $this, $vlan ) = @_;
    my $OID_dot1qVlanFdbId = '1.3.6.1.2.1.17.7.1.4.2.1.3.0';    #Q-BRIDGE-MIB
    my $logger = Log::Log4perl::get_logger( ref($this) );

    return $vlan;
}

=back

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2006-2010 Inverse inc.

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
