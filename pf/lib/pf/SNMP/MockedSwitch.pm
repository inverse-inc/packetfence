package pf::SNMP::MockedSwitch;

=head1 NAME

pf::SNMP::MockedSwitch - Fake switch module designed to document our interfaces and for tests

=head1 SYNOPSIS

pf::SNMP::MockedSwitch is first an exercice to be able to see what our pfsetvlan daemon does under stress. 
As it was implemented it became obvious that it would be useful to help us understand our own switch interfaces too.

This modules extends pf::SNMP.

=head1 STATUS

It's not complete yet

=head1 TODO

* all methods here should have at least one logger->debug statement and a realistic sleep based on what it does

* Full POD for pf::SNMP

* Add new subs from Cisco and friends that were added in trunk

* Create a pf::MockedWireless

=head1 BUGS AND LIMITATIONS

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use diagnostics;
use Carp;
use Log::Log4perl;
use Net::SNMP;
use Net::Appliance::Session;

use base ('pf::SNMP');


use pf::config;
# importing switch constants
use pf::SNMP::constants;

=head1 SUBROUTINES

Warning: The list of subroutine is incomplete

=over

=cut

# first, we are re-implementing all of pf::SNMP that has effects on switches to make sure it doesn't do anything

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

=item setVlanAllPort - set the port VLAN for all the non-UpLink ports of a switch

=cut

sub setVlanAllPort {
    my ( $this, $vlan, $switch_locker_ref ) = @_;
    my $oid_ifType = '1.3.6.1.2.1.2.2.1.3';    # MIB: ifTypes
    my @ports;

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
            $logger->debug("disabling port-security on ifIndex $ifIndex before resetting to vlan " . 
                           $this->{_normalVlan} );
            $this->setPortSecurityEnableByIfIndex($ifIndex, $FALSE);
        }
        $logger->debug( "setting " . $this->{_ip} . " ifIndex $ifIndex to VLAN " . $this->{_normalVlan} );
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

=item getSysName - return the administratively-assigned name of the switch. By convention, this is the switch's 
fully-qualified domain name
    
=cut
        
sub getSysName {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_sysName = '1.3.6.1.2.1.1.5';                     # mib-2
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysName: $OID_sysName");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$OID_sysName] );
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

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port ifAdminStatus");
        return 1;
    }

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
            $logger->trace("determining DHCP fingerprint info for $mac");
            my $node_info = node_view_with_fingerprint($mac);
            if ( defined($node_info)
                && ( $node_info->{dhcp_fingerprint} =~ /VoIP Phone/ ) )
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
    if ( defined($node_info) ) {
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
    $logger->trace(
        "determining if $mac is VoIP phone through discovery protocols");
    my @phones = $this->getPhonesDPAtIfIndex($ifIndex);
    return ( grep( { lc($_) eq lc($mac) } @phones ) != 0 );
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

sub isIfLinkUpDownTrapEnable { 
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_ifLinkUpDownTrapEnable = '1.3.6.1.2.1.31.1.1.1.14'; # from IF-MIB
    $logger->trace("SNMP get_request for ifLinkUpDownTrapEnable: $OID_ifLinkUpDownTrapEnable"); 
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [ "$OID_ifLinkUpDownTrapEnable.$ifIndex" ] );
    return ( exists( $result->{"$OID_ifLinkUpDownTrapEnable.$ifIndex"} )
                && ( $result->{"$OID_ifLinkUpDownTrapEnable.$ifIndex"} ne 'noSuchInstance' )
                && ( $result->{"$OID_ifLinkUpDownTrapEnable.$ifIndex"} == 1 ) );
}       

sub setIfLinkUpDownTrapEnable {
    my ( $this, $ifIndex, $enable ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port ifLinkUpDownTrapEnable");
        return 1;
    }   

    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $OID_ifLinkUpDownTrapEnable = '1.3.6.1.2.1.31.1.1.1.14'; # from IF-MIB
    my $truthValue = $enable ? $SNMP::TRUE : $SNMP::FALSE;

    $logger->trace("SNMP set_request for ifLinkUpDownTrapEnable: $OID_ifLinkUpDownTrapEnable");
    my $result = $this->{_sessionWrite}->set_request( -varbindlist => [ 
            "$OID_ifLinkUpDownTrapEnable.$ifIndex", Net::SNMP::INTEGER, $truthValue ] );
    return ( defined($result) );
}

sub getVersion {
    my ($this)       = @_;
    my $oid_sysDescr = '1.3.6.1.2.1.1.1.0';
    my $logger       = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysDescr: $oid_sysDescr");
    my $result = $this->{_sessionRead}
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
    my ( $this, $versionToCompareToString ) = @_;
    my $currentVersion = $this->getVersion();
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

sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );

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
        push @vlansToTest, $trapHashRef->{'trapVlan'};
        push @vlansToTest, $this->{'_macDetectionVlan'};
        foreach my $currentVlan ( @{ $this->{_vlans} } ) {
            if (   ( $currentVlan != $trapHashRef->{'trapVlan'} )
                && ( $currentVlan != $this->{'_macDetectionVlan'} ) )
            {
                push @vlansToTest, $currentVlan;
            }
        }
        my $found   = 0;
        my $vlanPos = 0;
        my $vlans   = $this->getVlans();
        while ( ( $vlanPos < scalar(@vlansToTest) ) && ( $found == 0 ) ) {
            my $currentVlan = $vlansToTest[$vlanPos];
            my $result      = undef;

            if ( exists( $vlans->{$currentVlan} ) ) {

                #issue correct SNMP query depending on SNMP version
                if ( $this->{_SNMPVersion} eq '3' ) {
                    if ( $this->connectRead() ) {
                        $logger->trace(
                            "SNMP get_request for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex.$dot1dBasePort"
                        );
                        $result = $this->{_sessionRead}->get_request(
                            -varbindlist =>
                                ["$OID_dot1dBasePortIfIndex.$dot1dBasePort"],
                            -contextname => "vlan_$currentVlan"
                        );
                    }
                } else {
                    my ( $sessionReadVlan, $sessionReadVlanError )
                        = Net::SNMP->session(
                        -hostname  => $this->{_ip},
                        -version   => $this->{_SNMPVersion},
                        -retries   => 1,
                        -timeout   => 2,
                        -community => $this->{_SNMPCommunityRead} . '@'
                            . $currentVlan
                        );
                    if ( defined($sessionReadVlan) ) {
                        $logger->trace(
                            "SNMP get_request for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex.$dot1dBasePort"
                        );
                        $result
                            = $sessionReadVlan->get_request( -varbindlist =>
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
        =~ /BEGIN VARIABLEBINDINGS .+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.4\.1\.9\.9\.315\.0\.0\.1[|]\.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.([0-9]+) = .+[|]\.1\.3\.6\.1\.4\.1\.9\.9\.315\.1\.2\.1\.1\.10\.[0-9]+ = Hex-STRING: ([0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2})/
        ) || ( $trapString
        =~ /BEGIN VARIABLEBINDINGS \.1\.3\.6\.1\.2\.1\.2\.2\.1\.1\.([0-9]+) = .+[|]\.1\.3\.6\.1\.4\.1\.9\.9\.315\.1\.2\.1\.1\.10\.[0-9]+ = Hex-STRING: ([0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2})/
        ) )
    {
        $trapHashRef->{'trapType'}    = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1;
        $trapHashRef->{'trapMac'}     = lc($2);
        $trapHashRef->{'trapMac'} =~ s/ /:/g;
        $trapHashRef->{'trapVlan'}
            = $this->getVlan( $trapHashRef->{'trapIfIndex'} );

        # CISCO-PORT-SECURITY-MIB cpsTrunkSecureMacAddrViolation
    } elsif ( $trapString
        =~ /BEGIN VARIABLEBINDINGS .+[|]\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: \.1\.3\.6\.1\.4\.1\.9\.9\.315\.0\.0\.2[|]\.1\.3\.6\.1\.2\.1\.31\.1\.1\.1\.1\.([0-9]+) = .+[|]\.1\.3\.6\.1\.4\.1\.9\.9\.315\.1\.2\.1\.1\.10\.[0-9]+ = Hex-STRING: ([0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2})/
        )
    {
        $trapHashRef->{'trapType'}    = 'secureMacAddrViolation';
        $trapHashRef->{'trapIfIndex'} = $1;
        $trapHashRef->{'trapMac'}     = lc($2);
        $trapHashRef->{'trapMac'} =~ s/ /:/g;
        $trapHashRef->{'trapVlan'}
            = $this->getVlan( $trapHashRef->{'trapIfIndex'} );

    #  IEEE802dot11-MIB dot11DeauthenticateReason + dot11DeauthenticateStation
    } elsif ( $trapString
        =~ /\.1\.2\.840\.10036\.1\.1\.1\.17\.[0-9]+ = INTEGER: [0-9]+[|]\.1\.2\.840\.10036\.1\.1\.1\.18\.[0-9]+ = Hex-STRING: ([0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2} [0-9A-Z]{2})/
        )
    {
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

sub getAllVlans {
    my ( $this, @ifIndexes ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $vlanHashRef;
    if ( !@ifIndexes ) {
        @ifIndexes = $this->getManagedIfIndexes();
    }

    my $OID_vmVlan
        = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';    #CISCO-VLAN-MEMBERSHIP-MIB
    my $OID_vlanTrunkPortNativeVlan
        = '1.3.6.1.4.1.9.9.46.1.6.1.1.5';    #CISCO-VTP-MIB

    if ( !$this->connectRead() ) {
        return $vlanHashRef;
    }
    $logger->trace("SNMP get_table for vmVlan: $OID_vmVlan");
    my $result = $this->{_sessionRead}->get_table( -baseoid => $OID_vmVlan );
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
        $logger->trace(
            "SNMP get_table for vlanTrunkPortNativeVlan: $OID_vlanTrunkPortNativeVlan"
        );
        $result = $this->{_sessionRead}
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

sub getVoiceVlan {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_vmVoiceVlanId
        = '1.3.6.1.4.1.9.9.68.1.5.1.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->trace(
        "SNMP get_request for vmVoiceVlanId: $OID_vmVoiceVlanId.$ifIndex");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_vmVoiceVlanId.$ifIndex"] );
    if ( exists( $result->{"$OID_vmVoiceVlanId.$ifIndex"} )
        && ( $result->{"$OID_vmVoiceVlanId.$ifIndex"} ne 'noSuchInstance' ) )
    {
        return $result->{"$OID_vmVoiceVlanId.$ifIndex"};
    } else {
        return -1;
    }
}

# TODO: if ifIndex doesn't exist, an error should be given
# to reproduce: bin/pfcmd_vlan -getVlan -ifIndex 999 -switch <ip>
sub getVlan {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_vmVlan
        = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->trace("SNMP get_request for vmVlan: $OID_vmVlan.$ifIndex");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_vmVlan.$ifIndex"] );
    if ( exists( $result->{"$OID_vmVlan.$ifIndex"} )
        && ( $result->{"$OID_vmVlan.$ifIndex"} ne 'noSuchInstance' ) )
    {
        return $result->{"$OID_vmVlan.$ifIndex"};
    } else {

        #this is a trunk port - try to get the trunk ports native VLAN
        my $OID_vlanTrunkPortNativeVlan
            = '1.3.6.1.4.1.9.9.46.1.6.1.1.5';    #CISCO-VTP-MIB
        $logger->trace(
            "SNMP get_request for vlanTrunkPortNativeVlan: $OID_vlanTrunkPortNativeVlan.$ifIndex"
        );
        my $result = $this->{_sessionRead}->get_request(
            -varbindlist => ["$OID_vlanTrunkPortNativeVlan.$ifIndex"] );
        return $result->{"$OID_vlanTrunkPortNativeVlan.$ifIndex"};
    }
}

sub isLearntTrapsEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_cmnMacAddrLearntEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.1';
    $logger->trace(
        "SNMP get_request for cmnMacAddrLearntEnable: $OID_cmnMacAddrLearntEnable"
    );
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => [ "$OID_cmnMacAddrLearntEnable.$ifIndex" ] );
    return (
        exists( $result->{"$OID_cmnMacAddrLearntEnable.$ifIndex"} )
            && ( $result->{"$OID_cmnMacAddrLearntEnable.$ifIndex"} ne 'noSuchInstance' )
            && ( $result->{"$OID_cmnMacAddrLearntEnable.$ifIndex"} ne 'noSuchObject' )
            && ( $result->{"$OID_cmnMacAddrLearntEnable.$ifIndex"} == 1 )
    );
}

sub setLearntTrapsEnabled {

    #1 means 'enabled', 2 means 'disabled'
    my ( $this, $ifIndex, $trueFalse ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $OID_cmnMacAddrLearntEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.1';
    $logger->trace(
        "SNMP set_request for cmnMacAddrLearntEnable: $OID_cmnMacAddrLearntEnable"
    );
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_cmnMacAddrLearntEnable.$ifIndex", Net::SNMP::INTEGER,
            $trueFalse
        ]
    );
    return ( defined($result) );
}

sub isRemovedTrapsEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_cmnMacAddrRemovedEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.2';
    $logger->debug(
        "SNMP get_request for cmnMacAddrRemovedEnable: $OID_cmnMacAddrRemovedEnable"
    );
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => [ "$OID_cmnMacAddrRemovedEnable.$ifIndex" ] );
    return (
        exists( $result->{"$OID_cmnMacAddrRemovedEnable.$ifIndex"} )
            && ( $result->{"$OID_cmnMacAddrRemovedEnable.$ifIndex"} ne
            'noSuchInstance' )
            && ( $result->{"$OID_cmnMacAddrRemovedEnable.$ifIndex"} == 1 )
    );
}

sub setRemovedTrapsEnabled {

    #1 means 'enabled', 2 means 'disabled'
    my ( $this, $ifIndex, $trueFalse ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $OID_cmnMacAddrRemovedEnable = '1.3.6.1.4.1.9.9.215.1.2.1.1.2';
    $logger->trace(
        "SNMP set_request for cmnMacAddrRemovedEnable: $OID_cmnMacAddrRemovedEnable"
    );
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_cmnMacAddrRemovedEnable.$ifIndex", Net::SNMP::INTEGER,
            $trueFalse
        ]
    );
    return ( defined($result) );
}

sub isPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    #CISCO-PORT-SECURITY-MIB
    my $OID_cpsIfPortSecurityEnable = '1.3.6.1.4.1.9.9.315.1.2.1.1.1';

    if ( !$this->connectRead() ) {
        return 0;
    }

    #determine if port security is enabled
    $logger->trace(
        "SNMP get_request for cpsIfPortSecurityEnable: $OID_cpsIfPortSecurityEnable.$ifIndex"
    );
    my $result = $this->{_sessionRead}->get_request(
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

sub _setVlan {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectWrite() ) {
        return 0;
    }

    my $removedTrapsEnabled = $this->isRemovedTrapsEnabled($ifIndex);
    if ($removedTrapsEnabled) {
        $logger->debug("disabling removed traps for port $ifIndex before VLAN change");
        $this->setRemovedTrapsEnabled( $ifIndex, $SNMP::FALSE );
    }

    my $result;
    if ( $this->isTrunkPort($ifIndex) ) {

        $result = $this->setTrunkPortNativeVlan($ifIndex, $newVlan);

        #expirer manuellement la mac-address-table
        $this->clearMacAddressTable( $ifIndex, $oldVlan );

    } else {
        my $OID_vmVlan = '1.3.6.1.4.1.9.9.68.1.2.2.1.2';    #CISCO-VLAN-MEMBERSHIP-MIB
        $logger->trace("SNMP set_request for vmVlan: $OID_vmVlan");
        $result = $this->{_sessionWrite}->set_request( -varbindlist =>[ 
            "$OID_vmVlan.$ifIndex", Net::SNMP::INTEGER, $newVlan ] );
    }
    my $returnValue = ( defined($result) );

    if ($removedTrapsEnabled) {
        $logger->debug("re-enabling removed traps for port $ifIndex after VLAN change");
        $this->setRemovedTrapsEnabled( $ifIndex, $SNMP::TRUE );
    }

    return $returnValue;
}

=item setTrunkPortNativeVlan - sets PVID on a trunk port

=cut
sub setTrunkPortNativeVlan {
    my ( $this, $ifIndex, $newVlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectWrite() ) {
        return 0;
    }

    my $result;
    my $OID_vlanTrunkPortNativeVlan = '1.3.6.1.4.1.9.9.46.1.6.1.1.5';    #CISCO-VTP-MIB
    $logger->trace("SNMP set_request for vlanTrunkPortNativeVlan: $OID_vlanTrunkPortNativeVlan");
    $result = $this->{_sessionWrite}->set_request( -varbindlist => [
        "$OID_vlanTrunkPortNativeVlan.$ifIndex", Net::SNMP::INTEGER, $newVlan] );

    return $result;

}

# fetch port type
# 1 => static
# 2 => dynamic
# 3 => multivlan
# 4 => trunk
sub getVmVlanType {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_vmVlanType
        = '1.3.6.1.4.1.9.9.68.1.2.2.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->trace(
        "SNMP get_request for vmVlanType: $OID_vmVlanType.$ifIndex");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_vmVlanType.$ifIndex"] );
    if ( exists( $result->{"$OID_vmVlanType.$ifIndex"} )
        && ( $result->{"$OID_vmVlanType.$ifIndex"} ne 'noSuchInstance' ) )
    {
        return $result->{"$OID_vmVlanType.$ifIndex"};
    } elsif ( $this->isTrunkPort($ifIndex) ) {
        return 4;
    } else {
        return 0;
    }
}

sub setVmVlanType {
    my ( $this, $ifIndex, $type ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->info( "setting port $ifIndex vmVlanType from "
            . $this->getVmVlanType($ifIndex)
            . " to $type" );
    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't change this port VmVlanType"
        );
        return 1;
    }
    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $OID_vmVlanType
        = '1.3.6.1.4.1.9.9.68.1.2.2.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
    $logger->trace("SNMP set_request for vmVlanType: $OID_vmVlanType");
    my $result = $this->{_sessionWrite}->set_request( -varbindlist =>
            [ "$OID_vmVlanType.$ifIndex", Net::SNMP::INTEGER, $type ] );
    return ( defined($result) );
}

=item getMacBridgePortHash

Cisco is very fancy about fetching it's VLAN information. In SNMPv3 the context 
is used to specify a VLAN and in SNMPv1/2c an @<vlan> is appended to the 
read-only community name when reading.

=cut
sub getMacBridgePortHash {
    my $this              = shift;
    my $vlan              = shift || '';
    my %macBridgePortHash = ();
    my $logger            = Log::Log4perl::get_logger( ref($this) );
    my $OID_dot1dTpFdbPort       = '1.3.6.1.2.1.17.4.3.1.2';    #BRIDGE-MIB
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB

    if ( !$this->connectRead() ) {
        return %macBridgePortHash;
    }

    #obtain ifPhysAddress array
    my $OID_ifPhysAddress = '1.3.6.1.2.1.2.2.1.6';
    $logger->trace("SNMP get_table for ifPhysAddress: $OID_ifPhysAddress");
    my $result
        = $this->{_sessionRead}->get_table( -baseoid => $OID_ifPhysAddress );
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
    if ( $this->{_SNMPVersion} eq '3' ) {
        $logger->trace(
            "SNMP v3 get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex"
        );
        $result = $this->{_sessionRead}->get_table(
            -baseoid     => $OID_dot1dBasePortIfIndex,
            -contextname => "vlan_$vlan"
        );
        foreach my $key ( keys %{$result} ) {
            $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
            $dot1dBasePortIfIndexHash{$1} = $result->{$key};
        }
        $logger->trace(
            "SNMP v3 get_table for dot1dTpFdbPort: $OID_dot1dTpFdbPort");
        $result = $this->{_sessionRead}->get_table(
            -baseoid     => $OID_dot1dTpFdbPort,
            -contextname => "vlan_$vlan"
        );
    } else {
        my ( $sessionReadVlan, $sessionReadVlanError ) = Net::SNMP->session(
            -hostname  => $this->{_ip},
            -version   => $this->{_SNMPVersion},
            -retries   => 1,
            -timeout   => 2,
            -community => $this->{_SNMPCommunityRead} . '@' . $vlan
        );

        if ( defined($sessionReadVlan) ) {

            #get dot1dBasePort to ifIndex association
            $logger->trace(
                "SNMP get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex"
            );
            $result = $sessionReadVlan->get_table(
                -baseoid => $OID_dot1dBasePortIfIndex );
            foreach my $key ( keys %{$result} ) {
                $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
                $dot1dBasePortIfIndexHash{$1} = $result->{$key};
            }
            $logger->trace(
                "SNMP get_table for dot1dTpFdbPort: $OID_dot1dTpFdbPort");
            $result = $sessionReadVlan->get_table(
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

sub getIfIndexForThisMac {
    my ( $this, $mac ) = @_;
    my $logger   = Log::Log4perl::get_logger( ref($this) );
    my @macParts = split( ':', $mac );
    my @uplinks  = $this->getUpLinks();
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

    foreach my $vlan ( @{ $this->{_vlans} } ) {
        my $result = undef;

        $logger->trace(
            "SNMP get_request for dot1dTpFdbPort: $oid on switch $this->{'_ip'}, VLAN $vlan"
        );

        if ( $this->{_SNMPVersion} eq '3' ) {
            $result = $this->{_sessionRead}->get_request(
                -varbindlist => [$oid],
                -contextname => "vlan_$vlan"
            );
            if ( defined($result) ) {
                my $dot1dPort = $result->{$oid};
                my $oid       = $OID_dot1dBasePortIfIndex . "." . $dot1dPort;
                my $result    = $this->{_sessionRead}->get_request(
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

            #connect to switch with the right VLAN information
            my ( $sessionReadVlan, $sessionReadVlanError )
                = Net::SNMP->session(
                -hostname  => $this->{_ip},
                -version   => $this->{_SNMPVersion},
                -retries   => 1,
                -timeout   => 2,
                -community => $this->{_SNMPCommunityRead} . '@' . $vlan
                );

            if ( defined($sessionReadVlan) ) {
                $result
                    = $sessionReadVlan->get_request( -varbindlist => [$oid] );
                if ( defined($result) ) {
                    my $dot1dPort = $result->{$oid};
                    my $oid    = $OID_dot1dBasePortIfIndex . "." . $dot1dPort;
                    my $result = $sessionReadVlan->get_request(
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

sub isMacInAddressTableAtIfIndex {
    my ( $this, $mac, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
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

    my $vlan = $this->getVlan($ifIndex);

    if ( $this->{_SNMPVersion} eq '3' ) {
        my $result = $this->{_sessionRead}->get_request(
            -varbindlist => [$oid],
            -contextname => "vlan_$vlan"
        );
        if ( defined($result) ) {
            my $dot1dPort = $result->{$oid};
            my $oid       = $OID_dot1dBasePortIfIndex . "." . $dot1dPort;
            $logger->trace(
                "SNMP get_request for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex"
            );
            my $result = $this->{_sessionRead}->get_request(
                -varbindlist => [$oid],
                -contextname => "vlan_$vlan"
            );
            if ( $result->{$oid} == $ifIndex ) {
                $logger->debug(
                    "mac $mac found on switch $this->{'_ip'}, VLAN $vlan, ifIndex $ifIndex"
                );
                return 1;
            }
        }

    } else {

        #connect to switch with the right VLAN information
        my ( $sessionReadVlan, $sessionReadVlanError ) = Net::SNMP->session(
            -hostname  => $this->{_ip},
            -version   => $this->{_SNMPVersion},
            -retries   => 1,
            -timeout   => 2,
            -community => $this->{_SNMPCommunityRead} . '@' . $vlan
        );

        if ( defined($sessionReadVlan) ) {
            $logger->trace(
                "SNMP get_request for dot1dBasePortIfIndex: $oid on switch $this->{'_ip'}, VLAN $vlan"
            );
            my $result
                = $sessionReadVlan->get_request( -varbindlist => [$oid] );
            if ( defined($result) ) {
                my $dot1dPort = $result->{$oid};
                my $oid       = $OID_dot1dBasePortIfIndex . "." . $dot1dPort;
                my $result
                    = $sessionReadVlan->get_request( -varbindlist => [$oid] );
                if ( $result->{$oid} == $ifIndex ) {
                    $logger->debug(
                        "mac $mac found on switch $this->{'_ip'}, VLAN $vlan, ifIndex $ifIndex"
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
        "MAC $mac could not be found on switch $this->{'_ip'}, VLAN $vlan, ifIndex $ifIndex"
    );
    return 0;
}

sub isTrunkPort {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_vlanTrunkPortDynamicState
        = "1.3.6.1.4.1.9.9.46.1.6.1.1.13";    #CISCO-VTP-MIB
    if ( !$this->connectRead() ) {
        return 0;
    }
    $logger->trace(
        "SNMP get_request for vlanTrunkPortDynamicState: $OID_vlanTrunkPortDynamicState"
    );
    my $result = $this->{_sessionRead}->get_request(
        -varbindlist => ["$OID_vlanTrunkPortDynamicState.$ifIndex"] );
    return (
        exists( $result->{"$OID_vlanTrunkPortDynamicState.$ifIndex"} )
            && ( $result->{"$OID_vlanTrunkPortDynamicState.$ifIndex"} ne
            'noSuchInstance' )
            && ( $result->{"$OID_vlanTrunkPortDynamicState.$ifIndex"} == 1 )
    );
}

=item setModeTrunk - sets a port as mode access or mode trunk

=cut
sub setModeTrunk {
    my ( $this, $ifIndex, $enable ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_vlanTrunkPortDynamicState = "1.3.6.1.4.1.9.9.46.1.6.1.1.13";    #CISCO-VTP-MIB

    # $mode = 1 -> switchport mode trunk
    # $mode = 2 -> switchport mode access

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port vlanTrunkPortDynamicState");
        return 1;
    }
    if ( !$this->connectWrite() ) {
        return 0;
    }

    my $truthValue = $enable ? $SNMP::TRUE : $SNMP::FALSE;
    $logger->trace("SNMP set_request for vlanTrunkPortDynamicState: $OID_vlanTrunkPortDynamicState");
    my $result = $this->{_sessionWrite}->set_request( -varbindlist => [ "$OID_vlanTrunkPortDynamicState.$ifIndex", 
        Net::SNMP::INTEGER, $truthValue ] );
    return ( defined($result) );
}

sub getVlans {
    my ($this)          = @_;
    my $vlans           = {};
    my $oid_vtpVlanName = '1.3.6.1.4.1.9.9.46.1.3.1.1.4.1';    #CISCO-VTP-MIB
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectRead() ) {
        return $vlans;
    }
    $logger->trace("SNMP get_request for vtpVlanName: $oid_vtpVlanName");
    my $result
        = $this->{_sessionRead}->get_table( -baseoid => $oid_vtpVlanName );
    if ( defined($result) ) {
        foreach my $key ( keys %{$result} ) {
            $key =~ /^$oid_vtpVlanName\.(\d+)$/;
            $vlans->{$1} = $result->{$key};
        }
    } else {
        $logger->info( "result is not defined at switch " . $this->{_ip} );
    }
    return $vlans;
}

sub isDefinedVlan {
    my ( $this, $vlan ) = @_;
    my $oid_vtpVlanName = '1.3.6.1.4.1.9.9.46.1.3.1.1.4.1';    #CISCO-VTP-MIB
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->connectRead() ) {
        return 0;
    }
    $logger->trace(
        "SNMP get_request for vtpVlanName: $oid_vtpVlanName.$vlan");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$oid_vtpVlanName.$vlan"] );
    return (   defined($result)
            && exists( $result->{"$oid_vtpVlanName.$vlan"} )
            && ( $result->{"$oid_vtpVlanName.$vlan"} ne 'noSuchInstance' ) );
}

sub getUpLinks {
    my $this = shift;
    my @ifIndex;
    my @upLinks;
    my $result;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( lc(@{ $this->{_uplink} }[0]) eq 'dynamic' ) {

        if ( !$this->connectRead() ) {
            return -1;
        }

        my $oid_cdpGlobalRun
            = '1.3.6.1.4.1.9.9.23.1.3.1'; # Is CDP enabled ? MIB: cdpGlobalRun
        $logger->trace("SNMP get_table for cdpGlobalRun: $oid_cdpGlobalRun");
        $result = $this->{_sessionRead}
            ->get_table( -baseoid => $oid_cdpGlobalRun );
        if ( defined($result) ) {

            my @cdpRun = values %{$result};
            if ( $cdpRun[0] == 1 ) {

                # CDP is enabled
                my $oid_cdpCachePlateform = '1.3.6.1.4.1.9.9.23.1.2.1.1.8';

                # fetch the upLinks. MIB: cdpCachePlateform
                $logger->trace(
                    "SNMP get_table for cdpCachePlateform: $oid_cdpCachePlateform"
                );
                $result = $this->{_sessionRead}->get_table(

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
                            . $this->{_ip}
                            . ": can not read cdpCachePlateform." );
                    return -1;
                }
            } else {
                $logger->debug(
                    "Problem while determining dynamic uplinks for switch "
                        . $this->{_ip}
                        . ": based on the config file, uplinks are dynamic but CDP is not enabled on this switch."
                );
                return -1;
            }
        } else {
            $logger->debug(
                      "Problem while determining dynamic uplinks for switch "
                    . $this->{_ip}
                    . ": can not read cdpGlobalRun." );
            return -1;
        }
    } else {
        @upLinks = @{ $this->{_uplink} };
    }
    return @upLinks;
}

=item getMacAddr

Warning: this method should _never_ be called in a thread. Net::Appliance::Session is not thread 
safe: 

L<http://www.cpanforum.com/threads/6909/>

=cut
sub getMacAddr {
    my ( $this, @managedPorts ) = @_;
    my $command;
    my $session;
    my @macAddressTable;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    eval {
        $session = Net::Appliance::Session->new(
            Host      => $this->{_ip},
            Timeout   => 5,
            Transport => $this->{_cliTransport}
        );
        $session->connect(
            Name     => $this->{_cliUser},
            Password => $this->{_cliPwd}
        );
    };

    if ($@) {
        $logger->error(
            "ERROR: Can not connect to switch $this->{'_ip'} using "
                . $this->{_cliTransport} );
        return @macAddressTable;
    }

    if ( scalar(@managedPorts) > 0 ) {
        $command = 'show mac-address-table | include '
            . $this->getRegExpFromList(@managedPorts);
    } else {
        $command = 'show mac-address-table';
    }
    $logger->trace("sending CLI command '$command'");
    my @tmp = $session->cmd($command);
    $logger->trace(
        "output of CLI command '$command':\n" . join( "\n", @tmp ) );

    foreach my $line (@tmp) {
        $line =~ s/\n//;
        push @macAddressTable, $line unless ( $line =~ /^$/ );
    }
    $session->close();
    return @macAddressTable;
}

sub getManagedIfIndexes {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my @managedIfIndexes;
    my @tmp_managedIfIndexes = $this->SUPER::getManagedIfIndexes();
    foreach my $ifIndex (@tmp_managedIfIndexes) {
        my $port_type = $this->getVmVlanType($ifIndex);
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

sub getMacAddrVlan {
    my $this = shift;
    my %macVlan;
    my @managedPorts = $this->getManagedPorts();
    my @macAddr;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    @macAddr = $this->getMacAddr(@managedPorts);

    my $ifDescMacVlan = $this->_getIfDescMacVlan(@macAddr);

    foreach my $ifDesc ( keys %$ifDescMacVlan ) {
        my @macs = keys %{ $ifDescMacVlan->{$ifDesc} };

        $logger->debug( "port: $ifDesc; number of MACs: " . scalar(@macs) );

        if ( scalar(@macs) == 1 ) {
            $macVlan{ $macs[0] }{'vlan'}
                = ${ $ifDescMacVlan->{$ifDesc}->{ $macs[0] } }[0];
            $macVlan{ $macs[0] }{'ifIndex'} = $ifDesc;
        } elsif ( scalar(@macs) > 1 ) {    # more than 1 MAC => hub
            my $macString = '';
            foreach my $mac (@macs) {
                $macString
                    .= "- $mac (Vlan :"
                    . join( ', ', @{ $ifDescMacVlan->{$ifDesc}->{$mac} } )
                    . ")\n";
            }
            chomp($macString);
            $logger->warn(
                "ALERT: There is a hub on switch $this->{'_ip'} port $ifDesc. We found the following "
                    . scalar(@macs)
                    . " MACs on this port:\n$macString" );
        }
    }
    $logger->debug("Show VLAN and port for every MAC (dumper):");
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
    my $OID_dot1dTpFdbPort       = '1.3.6.1.2.1.17.4.3.1.2';    #BRIDGE-MIB
    my $OID_dot1dBasePortIfIndex = '1.3.6.1.2.1.17.1.4.1.2';    #BRIDGE-MIB

    if ( !$this->connectRead() ) {
        return $ifIndexVlanMacHashRef;
    }

    #obtain ifPhysAddress array
    my $OID_ifPhysAddress = '1.3.6.1.2.1.2.2.1.6';
    $logger->trace("SNMP get_table for ifPhysAddress: $OID_ifPhysAddress");
    my $result
        = $this->{_sessionRead}->get_table( -baseoid => $OID_ifPhysAddress );
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

    my @vlansOnSwitch   = keys( %{ $this->getVlans() } );
    my @vlansToConsider = @{ $this->{_vlans} };
    if ( $this->isVoIPEnabled() ) {
        my $OID_vmVoiceVlanId
            = '1.3.6.1.4.1.9.9.68.1.5.1.1.1';    #CISCO-VLAN-MEMBERSHIP-MIB
        $logger->trace(
            "SNMP get_table for vmVoiceVlanId: $OID_vmVoiceVlanId");
        $result = $this->{_sessionRead}
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
            if ( $this->{_SNMPVersion} eq '3' ) {
                $logger->trace(
                    "SNMP v3 get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex"
                );
                $result = $this->{_sessionRead}->get_table(
                    -baseoid     => $OID_dot1dBasePortIfIndex,
                    -contextname => "vlan_$vlan"
                );
                foreach my $key ( keys %{$result} ) {
                    $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
                    $dot1dBasePortIfIndexHash{$1} = $result->{$key};
                }
                $logger->trace(
                    "SNMP v3 get_table for dot1dTpFdbPort: $OID_dot1dTpFdbPort"
                );
                $result = $this->{_sessionRead}->get_table(
                    -baseoid     => $OID_dot1dTpFdbPort,
                    -contextname => "vlan_$vlan"
                );
            } else {
                my ( $sessionReadVlan, $sessionReadVlanError )
                    = Net::SNMP->session(
                    -hostname  => $this->{_ip},
                    -version   => $this->{_SNMPVersion},
                    -retries   => 1,
                    -timeout   => 2,
                    -community => $this->{_SNMPCommunityRead} . '@' . $vlan
                    );

                if ( defined($sessionReadVlan) ) {

                    #get dot1dBasePort to ifIndex association
                    $logger->trace(
                        "SNMP get_table for dot1dBasePortIfIndex: $OID_dot1dBasePortIfIndex"
                    );
                    $result = $sessionReadVlan->get_table(
                        -baseoid => $OID_dot1dBasePortIfIndex );
                    foreach my $key ( keys %{$result} ) {
                        $key =~ /^$OID_dot1dBasePortIfIndex\.(\d+)$/;
                        $dot1dBasePortIfIndexHash{$1} = $result->{$key};
                    }
                    $logger->trace(
                        "SNMP get_table for dot1dTpFdbPort: $OID_dot1dTpFdbPort"
                    );
                    $result = $sessionReadVlan->get_table(
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

sub getHubs {
    my $this = shift;
    my $hubPorts;
    my @macAddr;
    my @managedPorts = $this->getManagedPorts();
    my $logger       = Log::Log4perl::get_logger( ref($this) );

    if (@managedPorts) {

        @macAddr = $this->getMacAddr(@managedPorts);

        my $ifDescMacVlan = $this->_getIfDescMacVlan(@macAddr);

        foreach my $ifDesc ( keys %$ifDescMacVlan ) {
            my @macs = keys %{ $ifDescMacVlan->{$ifDesc} };
            if ( scalar(@macs) > 1 ) {
                @{ $hubPorts->{$ifDesc} } = @macs;
            }
        }

    }
    return $hubPorts;
}

sub getPhonesDPAtIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my @phones;
    if ( !$this->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch "
                . $this->{_ip}
                . ". getPhonesDPAtIfIndex will return empty list." );
        return @phones;
    }
    return $this->getPhonesCDPAtIfIndex($ifIndex);
}

sub getPhonesCDPAtIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my @phones;
    if ( !$this->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch "
                . $this->{_ip}
                . ". getPhonesCDPAtIfIndex will return empty list." );
        return @phones;
    }
    my $oid_cdpCacheDeviceId = '1.3.6.1.4.1.9.9.23.1.2.1.1.6';
    my $oid_cdpCachePlatform = '1.3.6.1.4.1.9.9.23.1.2.1.1.8';
    if ( !$this->connectRead() ) {
        return @phones;
    }
    $logger->trace("SNMP get_next_request for $oid_cdpCachePlatform");
    my $result = $this->{_sessionRead}->get_next_request(
        -varbindlist => ["$oid_cdpCachePlatform.$ifIndex"] );
    foreach my $oid ( keys %{$result} ) {
        if ( $oid =~ /^$oid_cdpCachePlatform\.$ifIndex\.([0-9]+)$/ ) {
            my $cacheDeviceIndex = $1;
            if ( $result->{$oid} =~ /^Cisco IP Phone/ ) {
                $logger->trace("SNMP get_request for $oid_cdpCacheDeviceId");
                my $MACresult
                    = $this->{_sessionRead}->get_request( -varbindlist =>
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
    my ($this) = @_;
    return ( $this->{_VoIPEnabled} == 1 );
}

# type == 3 => startupConfig
# type == 4 => runningConfig
sub copyConfig {
    my ( $this, $type, $ip, $user, $pass, $filename ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $result;
    my $random;

    my $OID_ccCopyProtocol
        = '1.3.6.1.4.1.9.9.96.1.1.1.1.2';    #CISCO-CONFIG-COPY-MIB
    my $OID_ccCopySourceFileType = '1.3.6.1.4.1.9.9.96.1.1.1.1.3';
    my $OID_ccCopyDestFileType   = '1.3.6.1.4.1.9.9.96.1.1.1.1.4';
    my $OID_ccCopyServerAddress  = '1.3.6.1.4.1.9.9.96.1.1.1.1.5';
    my $OID_ccCopyFileName       = '1.3.6.1.4.1.9.9.96.1.1.1.1.6';
    my $OID_ccCopyUserName       = '1.3.6.1.4.1.9.9.96.1.1.1.1.7';
    my $OID_ccCopyUserPassword   = '1.3.6.1.4.1.9.9.96.1.1.1.1.8';
    my $OID_ccCopyState          = '1.3.6.1.4.1.9.9.96.1.1.1.1.10';
    my $OID_ccCopyEntryRowStatus = '1.3.6.1.4.1.9.9.96.1.1.1.1.14';

    if ( !$this->connectRead() ) {
        return 0;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    # generate random number
    my $nb = 0;
    do {
        $nb++;
        $random = 1 + int( rand(1000) );
        $logger->trace(
            "SNMP get_request for ccCopyEntryRowStatus: $OID_ccCopyEntryRowStatus.$random"
        );
        $result = $this->{_sessionRead}->get_request(
            -varbindlist => [ "$OID_ccCopyEntryRowStatus.$random" ] );
        if ( defined($result) ) {
            $logger->debug(
                "ccCopyTable row $random is already used - let's generate a new random number"
            );
        } else {
            $logger->debug(
                "ccCopyTable row $random is free - starting to create it");
        }
    } while ( ( $nb <= 20 ) && ( defined($result) ) );
    if ( $nb == 20 ) {
        $logger->error("unable to find unused entry in ccCopyTable");
        return 0;
    }

    $logger->trace(
        "SNMP set_request to create entry in ccCopyTable: $OID_ccCopyProtocol.$random i 2 $OID_ccCopySourceFileType.$random i $type $OID_ccCopyDestFileType.$random i 1 $OID_ccCopyServerAddress.$random a $ip $OID_ccCopyUserName.$random s $user $OID_ccCopyUserPassword.$random s $pass $OID_ccCopyFileName.$random s $filename $OID_ccCopyEntryRowStatus.$random i 4"
    );
    $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_ccCopyProtocol.$random",
            Net::SNMP::INTEGER,
            2,
            "$OID_ccCopySourceFileType.$random",
            Net::SNMP::INTEGER,
            $type,
            "$OID_ccCopyDestFileType.$random",
            Net::SNMP::INTEGER,
            1,
            "$OID_ccCopyServerAddress.$random",
            Net::SNMP::IPADDRESS,
            $ip,
            "$OID_ccCopyUserName.$random",
            Net::SNMP::OCTET_STRING,
            $user,
            "$OID_ccCopyUserPassword.$random",
            Net::SNMP::OCTET_STRING,
            $pass,
            "$OID_ccCopyFileName.$random",
            Net::SNMP::OCTET_STRING,
            $filename,
            "$OID_ccCopyEntryRowStatus.$random",
            Net::SNMP::INTEGER,
            4
        ]
    );

    if ( defined($result) ) {
        $logger->debug("ccCopyTable row $random successfully created");
        $nb = 0;
        do {
            $nb++;
            sleep(1);
            $logger->trace(
                "SNMP get_request for ccCopyState: $OID_ccCopyState.$random");
            $result = $this->{_sessionRead}->get_request(
                -varbindlist => [ "$OID_ccCopyState.$random" ] );
            } while ( ( $nb <= 120 )
            && defined($result)
            && ( $result->{"$OID_ccCopyState.$random"} == 2 ) );
        if ( $nb == 120 ) {
            $logger->error("copy operation seems not to complete");
            return 0;
        }

        $logger->debug("deleting ccCopyTable row $random");
        $logger->trace(
            "SNMP set_request for ccCopyEntryRowStatus: $OID_ccCopyEntryRowStatus.$random"
        );
        $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_ccCopyEntryRowStatus.$random", Net::SNMP::INTEGER, 6
            ]
        );
    } else {
        $logger->warn( "could not fill ccCopyTable row $random: "
                . $this->{_sessionWrite}->error() );
    }
    return ( defined($result) );

}

sub getManagedPorts {
    my $this       = shift;
    my $logger     = Log::Log4perl::get_logger( ref($this) );
    my $oid_ifType = '1.3.6.1.2.1.2.2.1.3';                     # MIB: ifTypes
    my $oid_ifName = '1.3.6.1.2.1.31.1.1.1.1';
    my @nonUpLinks;
    my @UpLinks = $this->getUpLinks();    # fetch the UpLink list

    if ( !$this->connectRead() ) {
        return @nonUpLinks;
    }
    $logger->trace("SNMP get_table for ifType: $oid_ifType");
    my $ifTypes = $this->{_sessionRead}
        ->get_table(    # fetch the ifTypes list of the ports
        -baseoid => $oid_ifType
        );
    if ( defined($ifTypes) ) {

        foreach my $port ( keys %{$ifTypes} ) {
            if ( $ifTypes->{$port} == 6 )
            {           # skip non ethernetCsmacd port type

                $port =~ /^$oid_ifType\.(\d+)$/;
                if ( grep( { $_ == $1 } @UpLinks ) == 0 ) {    # skip UpLinks

                    my $portVlan = $this->getVlan($1);
                    if ( defined $portVlan ) {    # skip port with no VLAN

                        my $port_type = $this->getVmVlanType($1);
                        if ( ( $port_type == 1 ) || ( $port_type == 4 ) )
                        {                         # skip non static

                            if (grep(
                                    { $_ == $portVlan } @{ $this->{_vlans} } )
                                != 0 )
                            {    # skip port in a non-managed VLAN
                                $logger->trace(
                                    "SNMP get_request for ifName: $oid_ifName.$1"
                                );
                                my $ifNames
                                    = $this->{_sessionRead}->get_request(
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
    my ( $this, @macAddr ) = @_;
    my $ifDescMacVlan;
    foreach my $line ( grep( {/DYNAMIC/} @macAddr ) ) {
        my ( $vlan, $mac, $ifDesc ) = unpack( "A4x4A14x16A*", $line );
        $mac =~ s/\./:/g;
        $mac = uc(
                  substr( $mac, 0, 2 ) . ':'
                . substr( $mac, 2,  5 ) . ':'
                . substr( $mac, 7,  5 ) . ':'
                . substr( $mac, 12, 2 ) );
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
    my ( $this, $ifIndex, $vlan ) = @_;
    my $command;
    my $session;
    my $oid_ifName = '1.3.6.1.2.1.31.1.1.1.1';
    my $logger     = Log::Log4perl::get_logger( ref($this) );

    eval {
        $session = Net::Appliance::Session->new(
            Host      => $this->{_ip},
            Timeout   => 5,
            Transport => $this->{_cliTransport}
        );
        $session->connect(
            Name     => $this->{_cliUser},
            Password => $this->{_cliPwd}
        );
        $session->begin_privileged( $this->{_cliEnablePwd} );
    };

    if ($@) {
        $logger->error(
            "ERROR: Can not connect to switch $this->{'_ip'} using "
                . $this->{_cliTransport} );
        return 0;
    }

    # First we fetch ifName(ifIndex)
    if ( !$this->connectRead() ) {
        return 0;
    }
    $logger->trace("SNMP get_request for ifName: $oid_ifName");
    my $ifNames = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$oid_ifName.$ifIndex"] );
    my $port = $ifNames->{"$oid_ifName.$ifIndex"};

    # then we clear the table with for ifDescr
    $command = "clear mac-address-table interface $port vlan $vlan";

    eval { $session->cmd( String => $command, Timeout => '10' ); };
    if ($@) {
        $logger->error(
            "ERROR: Error while clearing MAC Address table on port $ifIndex for switch $this->{'_ip'} using "
                . $this->{_cliTransport} );
        $session->close();
        return;
    }
    $session->close();
    return 1;
}

sub getMaxMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    #CISCO-PORT-SECURITY-MIB
    my $OID_cpsIfPortSecurityEnable = '1.3.6.1.4.1.9.9.315.1.2.1.1.1';
    my $OID_cpsIfMaxSecureMacAddr   = '1.3.6.1.4.1.9.9.315.1.2.1.1.3';

    if ( !$this->connectRead() ) {
        return -1;
    }

    #determine if port security is enabled
    $logger->trace(
        "SNMP get_request for cpsIfPortSecurityEnable: $OID_cpsIfPortSecurityEnable.$ifIndex"
    );
    my $result = $this->{_sessionRead}->get_request(
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
    $logger->trace(
        "SNMP get_request for cpsIfMaxSecureMacAddr: $OID_cpsIfMaxSecureMacAddr.$ifIndex"
    );
    $result = $this->{_sessionRead}->get_request(
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

=item ping

Warning: this method should _never_ be called in a thread. Net::Appliance::Session is not thread 
safe: 

L<http://www.cpanforum.com/threads/6909/>

=cut
sub ping {
    my ( $this, $ip ) = @_;
    my $session;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    eval {
        $session = Net::Appliance::Session->new(
            Host      => $this->{_ip},
            Timeout   => 5,
            Transport => $this->{_cliTransport}
        );
        $session->connect(
            Name     => $this->{_cliUser},
            Password => $this->{_cliPwd}
        );
    };

    if ($@) {
        $logger->error(
            "ERROR: Can not connect to switch $this->{'_ip'} using "
                . $this->{_cliTransport} );
        return 1;
    }

    if ( !$session->begin_privileged( $this->{_cliEnablePwd} ) ) {
        $logger->error( "ERROR: Cannot enable: " . $session->errmsg );
        $session->close();
        return 1;
    }

    $session->cmd("ping $ip timeout 0 repeat 1");
    $session->close();

    return 1;
}

=item supportsFloatingDevice - Does this switch type supports floating network devices ?

Only Catalyst 2900XL and 3500XL does not so far...

=cut
sub supportsFloatingDevice {
    my ( $this ) = @_;

    return 1;
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
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    my $maxSecureMacTotal;
    my $maxSecureMacVlanAccess = 1;

    if ($this->isVoIPEnabled()) {

        # switchport port-security maximum 2
        $maxSecureMacTotal = 2;
        $this->setPortSecurityMaxSecureMacAddrByIfIndex($ifIndex,$maxSecureMacTotal);

        # switchport port-security maximum 1 vlan access
        $this->setPortSecurityMaxSecureMacAddrVlanAccessByIfIndex($ifIndex,$maxSecureMacVlanAccess);
    } else {

        # switchport port-security maximum 1
        $maxSecureMacTotal = 1;
        $this->setPortSecurityMaxSecureMacAddrByIfIndex($ifIndex,$maxSecureMacTotal);
    }

    # switchport port-security violation restrict
    $this->setPortSecurityViolationActionByIfIndex($ifIndex, $CISCO::DROPNOTIFY);

    # switchport port-security mac-adress xxxx.xxxx.xxxx
    my $macToAuthorize;
    my @macArray = $this->_getMacAtIfIndex($ifIndex);
    if ( !@macArray ) {
        $macToAuthorize = $this->generateFakeMac(0, $ifIndex);
    } else {
        $macToAuthorize = $macArray[0];
    }
    my $vlan = $this->getVlan($ifIndex);
    $this->authorizeMAC( $ifIndex, undef, $macToAuthorize, $vlan, $vlan);

    # switchport port-security
    $this->setPortSecurityEnableByIfIndex($ifIndex, $TRUE);
    return 1;
}

=item disablePortSecurityByIfIndex - remove all the port-security settings on a port

=cut
sub disablePortSecurityByIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # no switchport port-security
    if (! $this->setPortSecurityEnableByIfIndex($ifIndex, $FALSE)) {
        $logger->error("An error occured while disablling port-security on ifIndex $ifIndex");
        return 0;
    }

    # no switchport port-security violation restrict
    if (! $this->setPortSecurityViolationActionByIfIndex($ifIndex, $CISCO::SHUTDOWN)) {
        $logger->error("An error occured while disablling port-security violation restrict in ifIndex $ifIndex");
        return 0;
    }

    # no switchport port-security mac-adress xxxx.xxxx.xxxx
    my $secureMacHashRef = $this->getSecureMacAddresses($ifIndex);
    my $valid = (ref($secureMacHashRef) eq 'HASH');
    my $mac_count = scalar(keys %{$secureMacHashRef});
    if ($valid && $mac_count == 1) {
        my $macToDeAuthorize = (keys %{$secureMacHashRef})[0];
        my $vlan = $this->getVlan($ifIndex);
        if (! $this->authorizeMAC( $ifIndex, $macToDeAuthorize, undef, $vlan, $vlan)) {
            $logger->error("An error occured while de-authorizing $macToDeAuthorize on ifIndex $ifIndex");
            return 0;
        }
    }

    return 1;
}

=item setPortSecurityEnableByIfIndex - enable/disable port-security on a port

=cut
sub setPortSecurityEnableByIfIndex {
    my ( $this, $ifIndex, $enable ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->warn("Should set IfPortSecurityEnable on $ifIndex to $enable but the switch is not in production -> Do nothing");
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $OID_cpsIfPortSecurityEnable = '1.3.6.1.4.1.9.9.315.1.2.1.1.1';
    my $truthValue = $enable ? $SNMP::TRUE : $SNMP::FALSE;

    $logger->trace("SNMP set_request for cpsIfPortSecurityEnable: $OID_cpsIfPortSecurityEnable");
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_cpsIfPortSecurityEnable.$ifIndex", Net::SNMP::INTEGER, $truthValue ] );
    return ( defined($result) );
}

=item setPortSecurityMaxSecureMacAddrByIfIndex 

Sets the global (data + voice) maximum number of MAC addresses for port-security on a port

=cut
sub setPortSecurityMaxSecureMacAddrByIfIndex {
    my ( $this, $ifIndex, $maxSecureMac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->warn("Should set IfMaxSecureMacAddr on $ifIndex to $maxSecureMac but the switch is not in production -> Do nothing");
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $OID_cpsIfMaxSecureMacAddr = '1.3.6.1.4.1.9.9.315.1.2.1.1.3';

    $logger->trace("SNMP set_request for IfMaxSecureMacAddr: $OID_cpsIfMaxSecureMacAddr");
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_cpsIfMaxSecureMacAddr.$ifIndex", Net::SNMP::INTEGER, $maxSecureMac ] );
   return ( defined($result) );
}

=item setPortSecurityMaxSecureMacAddrVlanByIfIndex 

Sets the maximum number of MAC addresses on the data vlan for port-security on a port

=cut
sub setPortSecurityMaxSecureMacAddrVlanAccessByIfIndex {
    my ( $this, $ifIndex, $maxSecureMac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->warn("Should set IfMaxSecureMacAddrPerVlan on $ifIndex to $maxSecureMac but the switch is not in production -> Do nothing");
        return 1;
    }

    my $ifName = $this->getIfName($ifIndex);
    if ($ifName eq '') {
        $logger->error( "Can not read ifName for ifIndex $ifIndex, Port-Security maximum can not be set on data Vlan");
        return 0;
    }

    my $session;
    eval {
        $session = Net::Appliance::Session->new(
            Host      => $this->{_ip},
            Timeout   => 5,
            Transport => $this->{_cliTransport}
        );
        $session->connect(
            Name     => $this->{_cliUser},
            Password => $this->{_cliPwd}
        );
    };

    if ($@) {
        $logger->error("Error connecting to " . $this->{'_ip'} . " using ".$this->{_cliTransport} . ". Error: $!");
    }

    # are we in enabled mode?
    if (!$session->in_privileged_mode()) {

        # let's try to enable
        if (!$session->enable($this->{_cliEnablePwd})) {
            $logger->error("Cannot get into privileged mode on ".$this->{'ip'}.
                           ". Are you sure you provided enable password in configuration?");
            $session->close();
            return 0;
        }
    }

    eval {
        $session->cmd(String => "conf t", Timeout => '10');
        $session->cmd(String => "int $ifName", Timeout => '10');
        $session->cmd(String => "switchport port-security maximum $maxSecureMac vlan access", Timeout => '10');
        $session->cmd(String => "end", Timeout => '10');
    };

    if ($@) {
        $logger->error("Error while configuring switchport port-security maximum $maxSecureMac vlan access on ifIndex "
                       . "$ifIndex. Error message: $!");
        $session->close();
        return 0;
    }

    $session->close();
    return 1;
}

=item setPortSecurityViolationActionByIfIndex 

Tells the switch what to do when the number of MAC addresses on the port has exceeded the maximum: shut down the port, send a trap or only allow traffic from the secure port and drop packets from other MAC addresses

=cut
sub setPortSecurityViolationActionByIfIndex {
    my ( $this, $ifIndex, $action ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->warn("Should set IfViolationAction on $ifIndex to $action but the switch is not in production -> Do nothing");
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $OID_cpsIfViolationAction = '1.3.6.1.4.1.9.9.315.1.2.1.1.8';

    $logger->trace("SNMP set_request for IfViolationAction: $OID_cpsIfViolationAction");
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [ "$OID_cpsIfViolationAction.$ifIndex", Net::SNMP::INTEGER, $action ] );
    return ( defined($result) );

}

=item setTaggedVlan 

Allows all the tagged Vlans on a multi-Vlan port. Used for floating network devices only 

=cut
sub setTaggedVlan {
    my ( $this, $ifIndex, @vlans ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    
    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port vlanTrunkPortVlansEnabled");
        return 1;
    }   
    
    if (! @vlans) {
        $logger->error("Tagged Vlan list is empty. Cannot set the tagged Vlans on trunk port $ifIndex");
        return 0;
    }   
        
    if ( !$this->connectWrite() ) {
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
        
    $logger->trace("SNMP set_request for OID_vlanTrunkPortVlansEnabled: $OID_vlanTrunkPortVlansEnabled");
    my $result = $this->{_sessionWrite}->set_request( -varbindlist => [
            "$OID_vlanTrunkPortVlansEnabled.$ifIndex", Net::SNMP::OCTET_STRING, $taggedVlanMembers,
            "$OID_vlanTrunkPortVlansEnabled2k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 0 x 1024),
            "$OID_vlanTrunkPortVlansEnabled3k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 0 x 1024),
            "$OID_vlanTrunkPortVlansEnabled4k.$ifIndex", Net::SNMP::OCTET_STRING, pack("B*", 0 x 1024) ] );
    return defined($result);
}   

=item removeAllTaggedVlan 

Removes all the tagged Vlans on a multi-Vlan port. Used for floating network devices only 

=cut
sub removeAllTaggedVlan {
    my ( $this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't change this port OID_vlanTrunkPortVlansEnabled");
        return 1;
    }

    if ( !$this->connectWrite() ) {
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

    my $result = $this->{_sessionWrite}->set_request( -varbindlist => [
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
    my ($this, $mac, $switch_port, $taggedVlans)  = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # switchport mode trunk
    $logger->info("Setting port $switch_port as trunk.");
    if (! $this->setModeTrunk($switch_port, $TRUE)) {
        $logger->error("An error occured while enabling port $switch_port as multi-vlan (trunk)");
        return 0;
    }

    # switchport trunk allowed vlan x,y,z
    $logger->info("Allowing tagged Vlans on port $switch_port");
    if (! $this->setTaggedVlan($switch_port, split(",", $taggedVlans)) ) {
        $logger->error("An error occured while allowing tagged Vlans on trunk port $switch_port");
        return 0;
    }

    # FIXME
    # this is one of the ugliest hack I did... For a mysterious reason if we don't wait 5 sec between the moment we set 
    # the port as trunk and the moment we enable linkdown traps, the switch port starts a never ending linkdown/linkup 
    # trap cycle. The problem would probably not occur if we could enable only linkdown traps without linkup. 
    # But we can't on Cisco's...
    sleep(5);

    return 1;
}

=item disablePortConfigAsTrunk - sets port as non multi-Vlan port

=cut
sub disablePortConfigAsTrunk {
    my ($this, $switch_port) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    # switchport mode access
    $logger->info("Setting port $switch_port as non trunk.");
    if (! $this->setModeTrunk($switch_port, $FALSE)) {
        $logger->error("An error occured while disabling port $switch_port as multi-vlan (trunk)");
        return 0;
    }

    # no switchport trunk allowed vlan
    # this setting is not necessary but we thought it would ease the reading of the port configuration if we remove
    # all the tagged vlan when they are not in use (port no longer trunk)
    $logger->info("Disabling tagged Vlans on port $switch_port");
    if (! $this->removeAllTaggedVlan($switch_port)) {
        $logger->warn("An minor issue occured while disabling tagged Vlans on trunk port $switch_port " .
                      "but the port should work.");
    }

    return 1;
}

=item dot1xPortReauthenticate - forces 802.1x re-authentication of a given ifIndex

ifIndex - ifIndex to force re-authentication on

=cut
sub dot1xPortReauthenticate {
    my ($this, $ifIndex) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    $logger->info("Trying generic MIB to force 802.1x port re-authentication. Your mileage may vary. "
        . "If it doesn't work open a bug report with your hardware type.");

    my $oid_dot1xPaePortReauthenticate = "1.0.8802.1.1.1.1.1.2.1.5"; # from IEEE8021-PAE-MIB

    if (!$this->connectWrite()) {
        return 0;
    }

    $logger->trace("SNMP set_request force dot1xPaePortReauthenticate on ifIndex: $ifIndex");
    my $result = $this->{_sessionWrite}->set_request(-varbindlist => [
        "$oid_dot1xPaePortReauthenticate.$ifIndex", Net::SNMP::INTEGER, 1
    ]);

    if (!defined($result)) {
        $logger->error("got an SNMP error trying to force 802.1x re-authentication: ".$this->{_sessionWrite}->error);
    }

    return (defined($result));
}

sub getMinOSVersion {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return '12.2(25)SEE2';
}

sub getAllSecureMacAddresses {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';

    my $secureMacAddrHashRef = {};
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for cpsIfVlanSecureMacAddrRowStatus: $oid_cpsIfVlanSecureMacAddrRowStatus"
    );
    my $result = $this->{_sessionRead}
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

sub isDynamicPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsIfVlanSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.3.1.3';

    if ( !$this->connectRead() ) {
        return 0;
    }
    if ( !$this->isPortSecurityEnabled($ifIndex) ) {
        $logger->debug("port security is not enabled");
        return 0;
    }

    $logger->trace(
        "SNMP get_table for cpsIfVlanSecureMacAddrType: $oid_cpsIfVlanSecureMacAddrType"
    );
    my $result = $this->{_sessionRead}
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

sub isStaticPortSecurityEnabled {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsIfVlanSecureMacAddrType = '1.3.6.1.4.1.9.9.315.1.2.3.1.3';

    if ( !$this->connectRead() ) {
        return 0;
    }
    if ( !$this->isPortSecurityEnabled($ifIndex) ) {
        $logger->info("port security is not enabled");
        return 0;
    }

    $logger->trace(
        "SNMP get_table for cpsIfVlanSecureMacAddrType: $oid_cpsIfVlanSecureMacAddrType"
    );
    my $result = $this->{_sessionRead}
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

sub getSecureMacAddresses {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';

    my $secureMacAddrHashRef = {};
    if ( !$this->connectRead() ) {
        return $secureMacAddrHashRef;
    }
    $logger->trace(
        "SNMP get_table for cpsIfVlanSecureMacAddrRowStatus: $oid_cpsIfVlanSecureMacAddrRowStatus"
    );
    my $result = $this->{_sessionRead}->get_table(
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

sub authorizeMAC {
    my ( $this, $ifIndex, $deauthMac, $authMac, $deauthVlan, $authVlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $oid_cpsIfVlanSecureMacAddrRowStatus = '1.3.6.1.4.1.9.9.315.1.2.3.1.5';

    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't add an entry to the SecureMacAddrTable"
        );
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    my $voiceVlan = $this->getVoiceVlan($ifIndex);
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
        $logger->trace(
            "SNMP set_request for cpsIfVlanSecureMacAddrRowStatus");
        my $result = $this->{_sessionWrite}
            ->set_request( -varbindlist => \@oid_value );
    }
    return 1;
}

sub NasPortToIfIndex {
    my ($this, $NAS_port) = @_;
    my $logger = Log::Log4perl::get_logger(ref($this));

    if ($NAS_port =~ s/^5/1/) {
        return $NAS_port;
    } else {
        $logger->warn("Unknown NAS-Port format. ifIndex translation could have failed. "
            ."VLAN re-assignment and switch/port accounting will be affected.");
    }
    return $NAS_port;
}

=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2010 Inverse inc.

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
