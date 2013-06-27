package pf::SNMP::Intel::Express_460;

=head1 NAME

pf::SNMP::Intel::Express_460 - Object oriented module to access SNMP enabled Intel Express 460 switches

=head1 SYNOPSIS

The pf::SNMP::Intel::Express_460 module implements an object oriented interface
to access SNMP enabled Cisco switches.

The minimum required firmware version is 4.60.89.

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=cut

use strict;
use warnings;
use Log::Log4perl;
use Net::SNMP;
use base ('pf::SNMP::Intel');

sub description { 'Intel Express 460' }

sub getMinOSVersion {
    my ($this) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    return '4.60.89';
}

sub getVersion {
    my ($this) = @_;
    my $oid_es400AgentRuntimeSwVersion = '1.3.6.1.4.1.343.6.17.1.1.1.0';
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace(
        "SNMP get_request for es400AgentRuntimeSwVersion: $oid_es400AgentRuntimeSwVersion"
    );
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => [$oid_es400AgentRuntimeSwVersion] );
    my $runtimeSwVersion
        = ( $result->{$oid_es400AgentRuntimeSwVersion} || '' );
    if ( $runtimeSwVersion =~ m/V(\d{1}\.\d{2}\.\d{2})/ ) {
        return $1;
    } else {
        return $runtimeSwVersion;
    }
}

sub getAllVlans {
    my ( $this, @ifIndexes ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $vlanHashRef;
    if ( !@ifIndexes ) {
        @ifIndexes = $this->getManagedIfIndexes();
    }
    my $OID_vlan = '1.3.6.1.2.1.17.7.1.4.4.1.1';
    if ( !$this->connectRead() ) {
        return $vlanHashRef;
    }
    $logger->trace("SNMP get_table for $OID_vlan");
    my $result = $this->{_sessionRead}->get_table( -baseoid => $OID_vlan );
    foreach my $key ( keys %{$result} ) {
        my $vlan = $result->{$key};
        $key =~ /^$OID_vlan\.(\d+)$/;
        my $ifIndex = $1;
        if ( grep( { $_ == $ifIndex } @ifIndexes ) > 0 ) {
            $vlanHashRef->{$ifIndex} = $vlan;
        }
    }
    return $vlanHashRef;
}

sub getVlan {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_vlan = '1.3.6.1.2.1.17.7.1.4.4.1.1';
    $logger->trace("SNMP get_request for $OID_vlan.$ifIndex");
    my $result = $this->{_sessionRead}
        ->get_request( -varbindlist => ["$OID_vlan.$ifIndex"] );
    return $result->{"$OID_vlan.$ifIndex"};
}

sub _setVlan {
    my ( $this, $ifIndex, $newVlan, $oldVlan, $switch_locker_ref ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return 0;
    }
    my $OID_pvid = '1.3.6.1.2.1.17.7.1.4.4.1.1';
    my $OID_dot1qVlanStaticEgressPorts
        = '1.3.6.1.2.1.17.7.1.4.3.1.2';    # Q-BRIDGE-MIB
    my $result;

    $logger->trace( "locking - trying to lock \$switch_locker{"
            . $this->{_id}
            . "} in _setVlan" );
    {
        lock %{ $switch_locker_ref->{ $this->{_id} } };
        $logger->trace( "locking - \$switch_locker{"
                . $this->{_id}
                . "} locked in _setVlan" );

        # get current egress ports
        $this->{_sessionRead}->translate(0);
        $logger->trace(
            "SNMP get_request for dot1qVlanStaticEgressPorts: $OID_dot1qVlanStaticEgressPorts.$oldVlan and $OID_dot1qVlanStaticEgressPorts.$newVlan"
        );
        $result = $this->{_sessionRead}->get_request(
            -varbindlist => [
                "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
                "$OID_dot1qVlanStaticEgressPorts.$newVlan",
            ]
        );

        #calculate new settings
        my $egressPortsOldVlan
            = $this->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticEgressPorts.$oldVlan"},
            $ifIndex - 1, 0 );
        my $egressPortsVlan
            = $this->modifyBitmask(
            $result->{"$OID_dot1qVlanStaticEgressPorts.$newVlan"},
            $ifIndex - 1, 1 );
        $this->{_sessionRead}->translate(1);

        # set all values
        if ( !$this->connectWrite() ) {
            return 0;
        }
        $logger->trace(
            "SNMP set_request for pvid and dot1qVlanStaticEgressPorts");
        $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [
                "$OID_pvid.$ifIndex",
                Net::SNMP::INTEGER,
                $newVlan,
                "$OID_dot1qVlanStaticEgressPorts.$oldVlan",
                Net::SNMP::OCTET_STRING,
                $egressPortsOldVlan,
                "$OID_dot1qVlanStaticEgressPorts.$newVlan",
                Net::SNMP::OCTET_STRING,
                $egressPortsVlan,
            ]
        );

        if ( !defined($result) ) {
            $logger->error(
                "error setting vlan: " . $this->{_sessionWrite}->error );
        }

        #set egress ports through web interface
        my $vlanName = $this->getVlans();
        $vlanName = $vlanName->{$newVlan};
        my $urlPath = $this->{_wsTransport} . '://' . $this->{_ip} . '/html/Hvlan_egresstag.html?';
        for ( my $i = 0; $i < length($vlanName); $i++ ) {
            my $char = substr( $vlanName, $i, 1 );
            $urlPath .= ord( substr( $vlanName, $i, 1 ) ) . ',';
        }
        $urlPath .= '0';

        eval {
            use LWP::UserAgent;
            use HTML::Form;

            my $ua = LWP::UserAgent->new;
            my $req = HTTP::Request->new( GET => $urlPath );
            $req->authorization_basic($this->{_wsUser}, $this->{_wsPwd});
            my $form = HTML::Form->parse( $ua->request($req) );
            $form->value( "S$ifIndex", '3' );
            $form->click('Submit');
            $req = $form->click('Submit');
            $req->authorization_basic($this->{_wsUser}, $this->{_wsPwd});
            my $response = $ua->request($req);
        };

        if ($@) {
            $logger->error("error setting VLAN: $@");
        }
    }
    $logger->trace( "locking - \$switch_locker{"
            . $this->{_id}
            . "} unlocked in _setVlan" );
    return 1;
}

sub setAdminStatus {
    my ( $this, $ifIndex, $enabled ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_es400PortConfigAdminState = '1.3.6.1.4.1.343.6.17.3.2.1.2';
    if ( !$this->connectWrite() ) {
        return 0;
    }
    $logger->trace(
        "SNMP set_request for es400PortConfigAdminState: $OID_es400PortConfigAdminState"
    );
    my $result = $this->{_sessionWrite}->set_request(
        -varbindlist => [
            "$OID_es400PortConfigAdminState.$ifIndex", Net::SNMP::INTEGER,
            ( $enabled ? 3 : 2 ),
        ]
    );
    return ( defined($result) );
}

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
