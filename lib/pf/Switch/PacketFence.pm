package pf::Switch::PacketFence;

=head1 NAME

pf::Switch::PacketFence - Object oriented module to send local traps to snmptrapd

=head1 SYNOPSIS

The pf::Switch::PacketFence module implements an object oriented interface
to send local SNMP traps to snmptrapd

=head1 SUBROUTINES

List incomplete.

=cut

use strict;
use warnings;

use base ('pf::Switch');
use Net::SNMP;

sub description { 'PacketFence' }

sub connectWrite {
    my $self   = shift;
    my $logger = $self->logger;
    if ( defined( $self->{_sessionWrite} ) ) {
        return 1;
    }
    $logger->debug("opening SNMP v1 connection to 127.0.0.1");
    ( $self->{_sessionWrite}, $self->{_error} ) = Net::SNMP->session(
        -hostname  => '127.0.0.1',
        -version   => 1,
        -port      => '162',
        -community => $self->{_SNMPCommunityTrap},
        -maxmsgsize => 4096
    );
    if ( !defined( $self->{_sessionWrite} ) ) {
        $logger->error( "error creating SNMP v1 connection to 127.0.0.1: "
                . $self->{_error} );
        return 0;
    }
    return 1;
}

sub sendLocalReAssignVlanTrap {
    my ($self, $switch, $ifIndex, $connection_type, $mac) = @_;
    my $switch_ip = $switch->{_ip};
    my $switch_id = $switch->{_id};
    my $logger = $self->logger;
    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $result;
    if (defined($mac)) {
        $result = $self->{_sessionWrite}->trap(
            -genericTrap => Net::SNMP::ENTERPRISE_SPECIFIC,
            -agentaddr   => $switch_ip,
            -varbindlist => [
                '1.3.6.1.6.3.1.1.4.1.0', Net::SNMP::OBJECT_IDENTIFIER, '1.3.6.1.4.1.29464.1.1',
                "1.3.6.1.2.1.2.2.1.1.$ifIndex", Net::SNMP::INTEGER,    $ifIndex,
                "1.3.6.1.2.1.2.2.1.1.$ifIndex", Net::SNMP::INTEGER,    $connection_type,
                "1.3.6.1.4.1.29464.1.3", Net::SNMP::OCTET_STRING,      $mac,
                "1.3.6.1.4.1.29464.1.5", Net::SNMP::OCTET_STRING,      $switch_id,
            ]
        );
    } else {
        $result = $self->{_sessionWrite}->trap(
            -genericTrap => Net::SNMP::ENTERPRISE_SPECIFIC,
            -agentaddr   => $switch_ip,
            -varbindlist => [
                '1.3.6.1.6.3.1.1.4.1.0', Net::SNMP::OBJECT_IDENTIFIER, '1.3.6.1.4.1.29464.1.1',
                "1.3.6.1.2.1.2.2.1.1.$ifIndex", Net::SNMP::INTEGER,    $ifIndex,
                "1.3.6.1.2.1.2.2.1.1.$ifIndex", Net::SNMP::INTEGER,    $connection_type,
                "1.3.6.1.4.1.29464.1.5", Net::SNMP::OCTET_STRING,      $switch_id,
            ]
        );
    }
    if ( !$result ) {
        $logger->error(
            "error sending SNMP trap: " . $self->{_sessionWrite}->error() );
    }
    return 1;
}

sub sendLocalDesAssociateTrap {
    my ($self, $switch, $mac, $connection_type) = @_;
    my $switch_ip = $switch->{_ip};
    my $switch_id = $switch->{_id};
    my $logger = $self->logger;
    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $result = $self->{_sessionWrite}->trap(
        -genericTrap => Net::SNMP::ENTERPRISE_SPECIFIC,
        -agentaddr   => $switch_ip,
        -varbindlist => [
            '1.3.6.1.6.3.1.1.4.1.0', Net::SNMP::OBJECT_IDENTIFIER, '1.3.6.1.4.1.29464.1.2',
            "1.3.6.1.4.1.29464.1.3", Net::SNMP::OCTET_STRING,      $mac,
            "1.3.6.1.4.1.29464.1.4", Net::SNMP::INTEGER,           $connection_type,
            "1.3.6.1.4.1.29464.1.5", Net::SNMP::OCTET_STRING,      $switch_id,
        ]
    );
    if ( !$result ) {
        $logger->error(
            "error sending SNMP trap: " . $self->{_sessionWrite}->error() );
    }
    return 1;
}

=head2 sendLocalFirewallRequestTrap

Sends a local trap meant to trigger firewall changes for pf::snmptrapd

=cut

sub sendLocalFirewallRequestTrap {
    my ($self, $switch, $mac) = @_;
    my $switch_ip = $switch->{_ip};
    my $switch_id = $switch->{_id};
    my $logger = $self->logger;
    if ( !$self->connectWrite() ) {
        return 0;
    }
    my $result = $self->{_sessionWrite}->trap(
        -genericTrap => Net::SNMP::ENTERPRISE_SPECIFIC,
        -agentaddr   => $switch_ip,
        -varbindlist => [
            '1.3.6.1.6.3.1.1.4.1.0', Net::SNMP::OBJECT_IDENTIFIER, '1.3.6.1.4.1.29464.1.3',
            "1.3.6.1.4.1.29464.1.3", Net::SNMP::OCTET_STRING,      $mac,
            "1.3.6.1.4.1.29464.1.5", Net::SNMP::OCTET_STRING,      $switch_id,
        ]
    );
    if ( !$result ) {
        $logger->error("error sending SNMP trap: " . $self->{_sessionWrite}->error());
    }
    return 1;
}


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

