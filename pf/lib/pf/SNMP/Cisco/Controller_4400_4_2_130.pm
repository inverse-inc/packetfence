package pf::SNMP::Cisco::Controller_4400_4_2_130;

=head1 NAME

pf::SNMP::Cisco::Controller_4400_4_2_130 - Object oriented module to access SNMP enabled Cisco Controller 4400 with IOS version 4.2.130

=head1 SYNOPSIS

The pf::SNMP::Cisco::Controller_4400_4_2_130 module implements an object oriented interface
to access SNMP enabled Cisco Controller 4400 with IOS version 4.2.130

=cut

use strict;
use warnings;
use diagnostics;

use base ('pf::SNMP::Cisco');
use Log::Log4perl;
use Carp;
use Net::SNMP;
use Net::Telnet;

sub deauthenticateMac {
    my ( $this, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $OID_bsnMobileStationDeleteAction = '1.3.6.1.4.1.14179.2.1.4.1.22';

    if ( !$this->isProductionMode() ) {
        $logger->info(
            "not in production mode ... we won't write to the bnsMobileStationTable"
        );
        return 1;
    }

    if ( !$this->connectWrite() ) {
        return 0;
    }

    #format MAC
    if ( length($mac) == 17 ) {
        my @macArray = split( /:/, $mac );
        my $completeOid = $OID_bsnMobileStationDeleteAction;
        foreach my $macPiece (@macArray) {
            $completeOid .= "." . hex($macPiece);
        }
        $logger->trace(
            "SNMP set_request for bsnMobileStationDeleteAction: $completeOid"
        );
        my $result = $this->{_sessionWrite}->set_request(
            -varbindlist => [ $completeOid, Net::SNMP::INTEGER, 1 ] );
        return ( defined($result) );
    } else {
        $logger->error(
            "ERROR: MAC format is incorrect ($mac). Should be xx:xx:xx:xx:xx:xx"
        );
        return 1;
    }
}

sub blacklistMac {
    my ( $this, $mac, $description ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( length($mac) == 17 ) {

        my $session;
        eval {
            $session = Net::Telnet->new(
                Host    => $this->{_ip},
                Timeout => 5,
                Prompt  => '/[\$%#>]$/'
            );
            $session->waitfor('/User: /');
            $session->put( $this->{_cliUser} . "\n" );
            $session->waitfor('/Password:/');
            $session->put( $this->{_cliPwd} . "\n" );
            $session->waitfor( $session->prompt );
        };

        if ($@) {
            $logger->error(
                "ERROR: Can not connect to access point $this->{'_ip'} using telnet"
            );
            return 1;
        }
        $logger->info("Blacklisting mac $mac");
        $session->cmd("config exclusionlist add $mac");
        $session->cmd(
            "config exclusionlist description $mac \"$description\"");
        $session->close();
    }
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
    $logger->debug("no DP is available on Controller 4400");
    return @phones;
}

sub isVoIPEnabled {
    my ($this) = @_;
    return 0;
}

=head1 BUGS AND LIMITATIONS

Controller issue with Windows 7: It only works with IOS > 6.x in 802.1x+WPA2. It's not a PacketFence issue.

With IOS 6.0.182.0 we had intermittent issues with DHCP. Disabling DHCP Proxy resolved it. Not a PacketFence issue.

=head1 AUTHOR

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2007-2008 Inverse inc.

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
