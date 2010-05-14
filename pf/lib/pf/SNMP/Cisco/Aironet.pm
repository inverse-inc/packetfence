package pf::SNMP::Cisco::Aironet;

=head1 NAME

pf::SNMP::Cisco::Aironet - Object oriented module to access SNMP enabled Cisco Aironet access points

=head1 SYNOPSIS

The pf::SNMP::Cisco::Aironet module implements an object oriented interface
to access SNMP enabled Aironet access points.

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

=head1 SUBROUTINES

TODO: This list is incomplete

=over

=item deauthenticateMac

Warning: this method should _never_ be called in a thread. Net::Appliance::Session is not thread 
safe: 

L<http://www.cpanforum.com/threads/6909/>

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
            "ERROR: Can not connect to access point $this->{'_ip'} using "
                . $this->{_cliTransport} );
        return 1;
    }

    #if (! $session->enable($this->{_cliEnablePwd})) {
    #    $logger->error("ERROR: Can not 'enable' telnet connection");
    #    return 1;
    #}
    $logger->info("Deauthenticating mac $mac");
    $session->cmd("clear dot11 client $mac");
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
    $logger->debug("no DP is available on Aironet");
    return @phones;
}

sub isVoIPEnabled {
    my ($this) = @_;
    return 0;
}

=back

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
