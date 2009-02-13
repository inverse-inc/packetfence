#
# Copyright 2007-2009 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#
#

package pf::SNMP::PacketFence;

=head1 NAME

pf::SNMP::PacketFence - Object oriented module to send local traps to snmptrapd


=head1 SYNOPSIS

The pf::SNMP::PacketFence module implements an object oriented interface
to send local SNMP traps to snmptrapd

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP');
use Log::Log4perl;
use Net::SNMP;

sub connectWrite {
    my $this   = shift;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( defined( $this->{_sessionWrite} ) ) {
        return 1;
    }
    $logger->debug("opening SNMP v1 connection to 127.0.0.1");
    ( $this->{_sessionWrite}, $this->{_error} ) = Net::SNMP->session(
        -hostname  => '127.0.0.1',
        -version   => 1,
        -port      => '162',
        -community => $this->{_SNMPCommunityTrap}
    );
    if ( !defined( $this->{_sessionWrite} ) ) {
        $logger->error( "error creating SNMP v1 connection to 127.0.0.1: "
                . $this->{_error} );
        return 0;
    }
    return 1;
}

sub sendLocalReAssignVlanTrap {
    my ( $this, $switch_ip, $ifIndex ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $result = $this->{_sessionWrite}->trap(
        -genericTrap => Net::SNMP::ENTERPRISE_SPECIFIC,
        -agentaddr   => $switch_ip,
        -varbindlist => [
            '1.3.6.1.6.3.1.1.4.1.0', Net::SNMP::OBJECT_IDENTIFIER,
            '1.3.6.1.4.1.29464.1.1', "1.3.6.1.2.1.2.2.1.1.$ifIndex",
            Net::SNMP::INTEGER,      $ifIndex,
        ]
    );
    if ( !$result ) {
        $logger->error(
            "error sending SNMP trap: " . $this->{_sessionWrite}->error() );
    }
    return 1;
}

sub sendLocalDesAssociateTrap {
    my ( $this, $switch_ip, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectWrite() ) {
        return 0;
    }
    my $result = $this->{_sessionWrite}->trap(
        -genericTrap => Net::SNMP::ENTERPRISE_SPECIFIC,
        -agentaddr   => $switch_ip,
        -varbindlist => [
            '1.3.6.1.6.3.1.1.4.1.0', Net::SNMP::OBJECT_IDENTIFIER,
            '1.3.6.1.4.1.29464.1.2', "1.3.6.1.4.1.29464.1.3",
            Net::SNMP::OCTET_STRING, $mac,
        ]
    );
    if ( !$result ) {
        $logger->error(
            "error sending SNMP trap: " . $this->{_sessionWrite}->error() );
    }
    return 1;
}

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

