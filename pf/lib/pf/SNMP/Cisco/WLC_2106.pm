package pf::SNMP::Cisco::WLC_2106;

=head1 NAME

pf::SNMP::Cisco::WLC_2106

=head1 SYNOPSIS

The pf::SNMP::Cisco::WLC_2106 module implements an object oriented interface to manage Wireless LAN Controllers.

=cut

=head1 BUGS AND LIMITATIONS

Wireless deauthentication (deassociation) uses the CLI (telnet or ssh) which is expensive (doesn't scale very well).

=cut

use strict;
use warnings;
use diagnostics;

use Carp;
use Log::Log4perl;
use Net::Appliance::Session;
use Net::SNMP;

use base ('pf::SNMP::Cisco');

use pf::config;

=head1 SUBROUTINES

TODO: This list is incomplete

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
# special features 
sub supportsSaveConfig { return $FALSE; }


=item deauthenticateMac

Warning: this method should _never_ be called in a thread. Net::Appliance::Session is not thread 
safe: 

L<http://www.cpanforum.com/threads/6909/>

Warning: this code doesn't support elevating to privileged mode. See #900 and #1370.

=cut
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
        # Session not already privileged are not supported at this point. See #1370
        #$session->begin_privileged( $this->{_cliEnablePwd} );
        $session->do_privileged_mode(0);
        $session->begin_configure();
    };

    if ($@) {
        $logger->error( "ERROR: Can not connect to WLC $this->{'_ip'} using "
                . $this->{_cliTransport} );
        return 1;
    }

    #if (! $session->enable($this->{_cliEnablePwd})) {
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

=back

=head1 BUGS AND LIMITATIONS

Controller issue with Windows 7: It only works with IOS > 6.x in 802.1x+WPA2. It's not a PacketFence issue.

With IOS 6.0.182.0 we had intermittent issues with DHCP. Disabling DHCP Proxy resolved it. Not a PacketFence issue.

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Dominik Gehl <dgehl@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2007-2012 Inverse inc.

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
