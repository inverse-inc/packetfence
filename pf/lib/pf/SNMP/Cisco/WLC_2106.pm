#
# Copyright 2007-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#

package pf::SNMP::Cisco::WLC_2106;

=head1 NAME

pf::SNMP::Cisco::WLC_2106 - Object oriented module to access SNMP enabled Cisco WLC


=head1 SYNOPSIS

The pf::SNMP::Cisco::WLC_2106 module implements an object oriented interface
to access SNMP enabled Wireless LAN Controllers.

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP::Cisco');
use Log::Log4perl;
use Carp;
use Net::Appliance::Session;
use Net::SNMP;
use Data::Dumper;

sub deauthenticateMac {
    my ( $this, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    #format MAC
    if ( length($mac) == 17 ) {
        $mac =~ s/://g;
        $mac
            = substr( $mac, 0, 4 ) . "."
            . substr( $mac, 4, 4 ) . "."
            . substr( $mac, 8, 4 );
    } else {
        $logger->error(
            "ERROR: MAC format is incorrect ($mac). Should be xx:xx:xx:xx:xx:xx"
        );
        return 1;
    }

    my $session;
    eval {
        $session = new Net::Appliance::Session->new(
            Host      => $this->{_ip},
            Timeout   => 5,
            Transport => $this->{_cliTransport}
        );
        $session->connect(
            Name     => $this->{_cliUser},
            Password => $this->{_cliPwd}
        );
        $session->begin_privileged( $this->{_cliEnablePwd} );
        $session->begin_configure();
    };

    if ($@) {
        $logger->error( "ERROR: Can not connect to WLC $this->{'_ip'} using "
                . $this->{_cliTransport} );
        return 1;
    }

    #if (! $session->enable($this->{_telnetEnablePwd})) {
    #    $logger->error("ERROR: Can not 'enable' telnet connection");
    #    return 1;
    #}
    $session->cmd("client deauthenticate $mac");
    $session->close();

    return 1;
}

sub isLearntTrapsEnabled {
    my ( $this, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub setLearntTrapsEnabled {
    my ( $this, $ifIndex, $trueFalse ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return -1;
}

sub isRemovedTrapsEnabled {
    my ( $this, $ifIndex ) = @_;
    return ( 0 == 1 );
}

sub setRemovedTrapsEnabled {
    my ( $this, $ifIndex, $trueFalse ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return -1;
}

sub getVmVlanType {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return -1;
}

sub setVmVlanType {
    my ( $this, $ifIndex, $type ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return -1;
}

sub isTrunkPort {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return -1;
}

sub getVlans {
    my ($this) = @_;
    my $vlans  = {};
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return $vlans;
}

sub isDefinedVlan {
    my ( $this, $vlan ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    $logger->error("function is NOT implemented");
    return 0;
}

sub getPhonesDPAtIfIndex {
    my ( $this, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my @phones = ();
    if ( !$this->isVoIPEnabled() ) {
        $logger->debug( "VoIP not enabled on switch "
                . $this->{_ip}
                . ". getPhonesDPAtIfIndex will return empty list." );
        return @phones;
    }
    $logger->debug("no DP is available on WLC_2106");
    return @phones;
}

sub isVoIPEnabled {
    my ($this) = @_;
    return 0;
}

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
