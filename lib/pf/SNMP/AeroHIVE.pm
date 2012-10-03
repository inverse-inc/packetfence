package pf::SNMP::AeroHIVE;

=head1 NAME

pf::SNMP::AeroHIVE

=head1 SYNOPSIS

Module to manage AeroHIVE APs

=head1 STATUS

Developed and tested on AeroHIVE AP 320 running firmware 3 something.

=over

=item Supports

=over

=item Deauthentication with RADIUS Disconnect (RFC3576)

=item Deauthentication with SNMP

=item Role-based access control

=back

=back

=head1 BUGS AND LIMITATIONS

Nothing documented at this point.

=cut
use strict;
use warnings;

use Log::Log4perl;
use Net::Appliance::Session;
use Try::Tiny;

use base ('pf::SNMP');

use pf::config;
# RADIUS constants (RADIUS:: namespace)
use pf::radius::constants;
use pf::roles::custom $ROLE_API_LEVEL;
# importing switch constants
use pf::SNMP::constants;
use pf::util;

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsRoleBasedEnforcement { return $TRUE; }
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }

=item getVersion

obtain image version information from switch

=cut
sub getVersion {
    my ($this) = @_;
    my $oid_AeroHiveSoftwareVersion = '1.3.6.1.2.1.1.1.0'; #
    my $logger = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }

    $logger->trace("SNMP get_request for AeroHiveSoftwareVersion: $oid_AeroHiveSoftwareVersion");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$oid_AeroHiveSoftwareVersion] );
    if (defined($result)) {
        return $result->{$oid_AeroHiveSoftwareVersion};
    }

    # none of the above worked
    $logger->warn("unable to fetch version information");
}

=item parseTrap

This is called when we receive an SNMP-Trap for this device

=cut
sub parseTrap {
    my ( $this, $trapString ) = @_;
    my $trapHashRef;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    $logger->debug("trap currently not handled");
    $trapHashRef->{'trapType'} = 'unknown';

    return $trapHashRef;
}

=item deauthenticateMacDefault 

De-authenticate a MAC address from wireless network (including 802.1x).

New implementation using RADIUS Disconnect-Request.

=cut
sub deauthenticateMacDefault {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    return $self->radiusDisconnect($mac);
}

=item _deauthenticateMacTelnet

** DEPRECATED

deauthenticate a MAC address from wireless network

Right now te only way to do it is from the CLi (through Telnet or SSH).

Warning: this code doesn't support elevating to privileged mode. See #900 and #1370.

=cut
sub _deauthenticateMacTelnet {
    my ( $this, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );

    if ( !$this->isProductionMode() ) {
        $logger->info("not in production mode ... we won't deauthenticate $mac");
        return 1;
    }

    if ( length($mac) != 17 ) {
        $logger->error("MAC format is incorrect ($mac). Should be xx:xx:xx:xx:xx:xx");
        return 1;
    }

    my $session;
    eval {
        $session = Net::Appliance::Session->new(
            Host      => $this->{_ip},
            Timeout   => 5,
            Transport => $this->{_cliTransport},
            Platform => 'HiveOS',
            Source   => $lib_dir.'/pf/SNMP/AeroHIVE/nas-pb.yml'
        );
        $session->connect(
            Name     => $this->{_cliUser},
            Password => $this->{_cliPwd}
        );
    };

    if ($@) {
        $logger->error("Unable to connect to ".$this->{'_ip'}." using ".$this->{_cliTransport}.". Failed with $@");
        return;
    }

    # if $session->begin_configure() does not work, use the following command:
    my $command = "clear auth station mac $mac";

    $logger->info("Deauthenticating mac $mac");
    $logger->trace("sending CLI command '$command'");
    my @output;
    $session->in_privileged_mode(1);
    eval { 
        @output = $session->cmd(String => $command, Timeout => '10');
    };
    $session->in_privileged_mode(0);
    if ($@) {
        $logger->error("Unable to deauthenticate $mac: $@");        
        $session->close();
        return;
    }
    $session->close();
    return 1;
}

=item returnRadiusAccessAccept

Overloading L<pf::SNMP>'s implementation because AeroHIVE doesn't support 
assigning VLANs and Roles at the same time.

=cut
sub returnRadiusAccessAccept {
    my ($self, $vlan, $mac, $port, $connection_type, $user_name, $ssid) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    my $radius_reply_ref = {};

    # TODO this is experimental
    try {

        $logger->debug("network device supports roles. Evaluating role to be returned");
        my $roleResolver = pf::roles::custom->instance();
        my $role = $roleResolver->getRoleForNode($mac, $self);

        # Roles are configured and the user should have one
        if (defined($role)) {

            $radius_reply_ref = {
                'Tunnel-Medium-Type' => $RADIUS::IP,
                'Tunnel-Type' => $RADIUS::GRE,
                'Tunnel-Private-Group-ID' => $role,
            };

            $logger->info("Returning ACCEPT with Role: $role");
        }

        # if Roles aren't configured, return VLAN information
        else {

            $radius_reply_ref = {
                'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
                'Tunnel-Type' => $RADIUS::VLAN,
                'Tunnel-Private-Group-ID' => $vlan,
            };

            $logger->info("Returning ACCEPT with VLAN: $vlan");
        }

    }
    catch {
        chomp($_);
        $logger->debug(
            "Exception when trying to resolve a Role for the node. Returning VLAN attributes in RADIUS Access-Accept. "
            . "Exception: $_"
        );

        $radius_reply_ref = {
            'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
            'Tunnel-Type' => $RADIUS::VLAN,
            'Tunnel-Private-Group-ID' => $vlan,
        };
    };

    return [$RADIUS::RLM_MODULE_OK, %$radius_reply_ref];
}

=item returnRoleAttribute

AeroHive assigns roles differently, see it's implementation of returnRadiusAccessAccept.

This stub is here otherwise roles support tests fails since we expect an returnRoleAttribute implementation.

=cut
sub returnRoleAttribute {
    my ($this) = @_;
    return;
}


=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($this, $method) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $default = $SNMP::RADIUS;
    my %tech = (
        $SNMP::RADIUS => \&deauthenticateMacDefault,
        $SNMP::TELNET  => \&_deauthenticateMacTelnet,
    );

    if (!exists($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}


=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

Francois Gaudreault <fgaudreault@inverse.ca>

Fabrice Durand <fdurand@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2010, 2011, 2012 Inverse inc.

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
