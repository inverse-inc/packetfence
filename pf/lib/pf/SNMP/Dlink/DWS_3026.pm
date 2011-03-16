package pf::SNMP::Dlink::DWS_3026;

=head1 NAME

pf::SNMP::Dlink::DWS_3026

=head1 SYNOPSIS

The pf::SNMP::Dlink::DWS_3026 module implements an object oriented interface
to manage Dlink DWS 3026 controller.

=cut

use strict;
use warnings;
use diagnostics;

use Log::Log4perl;
use Net::SNMP;

use base ('pf::SNMP::Dlink');

use pf::config;

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }

sub deauthenticateMac {
    my ( $this, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_wsAssociatedClientDisassociateAction = '1.3.6.1.4.1.171.10.73.30.9.1.1.9';

    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't write to wsAssociatedClientDisassociateAction"
        );
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    #format MAC
    if ( length($mac) == 17 ) {
        my @macArray = split( /:/, $mac );
        my $completeOid = $OID_wsAssociatedClientDisassociateAction;
        foreach my $macPiece (@macArray) {
            $completeOid .= "." . hex($macPiece);
        }
        $logger->trace(
            "SNMP set_request for wsAssociatedClientDisassociateAction: $completeOid"
        );
        my $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [ $completeOid, Net::SNMP::INTEGER, 2 ] );
        return ( defined($result) );
    } else {
        $logger->error(
            "ERROR: MAC format is incorrect ($mac). Should be xx:xx:xx:xx:xx:xx"
        );
        return 1;
    }
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
    $logger->debug("no DP is available on DWS 3026");
    return @phones;
}

sub isVoIPEnabled {
    my ($this) = @_;
    return 0;
}

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2009-2011 Inverse inc.

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
