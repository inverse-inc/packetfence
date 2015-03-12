package pf::Switch::Mikrotik;


=head1 NAME

pf::Switch::Mikrotik

=head1 SYNOPSIS

The pf::Switch::Mikrotik module manages access to Mikrotik APs

=head1 STATUS

Should work on CAPsMAN enabled APs, tested on v6.18

=cut

use strict;
use warnings;

use Log::Log4perl;
use Net::SSH2;
use POSIX;
use Try::Tiny;

use base ('pf::Switch');

use pf::constants;
use pf::config;
sub description { 'Mikrotik' }

# importing switch constants
use pf::Switch::constants;
use pf::util;
use pf::util::radius qw(perform_disconnect);

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsWirelessMacAuth { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }


=item getVersion - obtain image version information from switch

=cut

sub getVersion {
    my ($this)       = @_;
    my $oid_sysDescr = '1.3.6.1.4.1.14988.1.1.4.4.0';
    my $logger       = Log::Log4perl::get_logger( ref($this) );
    if ( !$this->connectRead() ) {
        return '';
    }
    $logger->trace("SNMP get_request for sysDescr: $oid_sysDescr");
    my $result = $this->{_sessionRead}->get_request( -varbindlist => [$oid_sysDescr] );
    my $sysDescr = ( $result->{$oid_sysDescr} || '' );
    return $sysDescr;
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($this, $method) = @_;
    my $logger = Log::Log4perl::get_logger( ref($this) );
    my $default = $SNMP::SSH;
    my %tech = (
        $SNMP::SSH    => 'deauthenticateMacSSH',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}

=item deauthenticateMacDefault

De-authenticate a MAC address from wireless network (including 802.1x).

New implementation using RADIUS Disconnect-Request.

This method has been kept since we will probably use this deauth method in the future

=cut

sub deauthenticateMacRadius {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    $logger->debug("deauthenticate $mac using RADIUS Disconnect-Request deauth method");
    return $self->radiusDisconnect($mac);
}

=item radiusDisconnect

Sends a RADIUS Disconnect-Request to the NAS with the MAC as the Calling-Station-Id to disconnect.

Has been tested with 6.18 Mikrotik OS version and doesn´t work yet

Uses L<pf::util::radius> for the low-level RADIUS stuff.

=cut

# TODO consider whether we should handle retries or not?

sub radiusDisconnect {
    my ($self, $mac, $add_attributes_ref) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    # initialize
    $add_attributes_ref = {} if (!defined($add_attributes_ref));

    if (!defined($self->{'_radiusSecret'})) {
        $logger->warn(
            "Unable to perform RADIUS Disconnect-Request on $self->{'_ip'}: RADIUS Shared Secret not configured"
        );
        return;
    }

    $logger->info("deauthenticating $mac");

    # Where should we send the RADIUS Disconnect-Request?
    # to network device by default
    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }
    # allowing client code to override where we connect with NAS-IP-Address
    $send_disconnect_to = $add_attributes_ref->{'NAS-IP-Address'}
        if (defined($add_attributes_ref->{'NAS-IP-Address'}));

    my $response;
    try {
        my $connection_info = {
            nas_ip => $send_disconnect_to,
            secret => $self->{'_radiusSecret'},
            LocalAddr => $management_network->tag('vip'),
        };

        # transforming MAC to the expected format 00-11-22-33-CA-FE
        $mac = uc($mac);
        $mac =~ s/:/-/g;

        # Standard Attributes
        my $attributes_ref = {
            'Calling-Station-Id' => $mac,
        };

        # merging additional attributes provided by caller to the standard attributes
        $attributes_ref = { %$attributes_ref, %$add_attributes_ref };

        $response = perform_disconnect($connection_info, $attributes_ref);
    } catch {
        chomp;
        $logger->warn("Unable to perform RADIUS Disconnect-Request: $_");
        $logger->error("Wrong RADIUS secret or unreachable network device...") if ($_ =~ /^Timeout/);
    };
    return if (!defined($response));

    return $TRUE if ($response->{'Code'} eq 'Disconnect-ACK');

    $logger->warn(
        "Unable to perform RADIUS Disconnect-Request."
        . ( defined($response->{'Code'}) ? " $response->{'Code'}" : 'no RADIUS code' ) . ' received'
        . ( defined($response->{'Error-Cause'}) ? " with Error-Cause: $response->{'Error-Cause'}." : '' )
    );
    return;
}

=item returnRadiusAccessAccept

Overloading L<pf::Switch>'s implementation because Mikrotik have his own radius attributes.

Don't forget to fill /usr/share/freeradius/dictionary.mikrotik with the following attributes:

ATTRIBUTE       Mikrotik-Wireless-VlanID                26      integer
ATTRIBUTE       Mikrotik-Wireless-VlanIDType            27      integer

=cut

sub returnRadiusAccessAccept {
    my ($self, $vlan, $mac, $port, $connection_type, $user_name, $ssid, $wasInline, $user_role) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    # Inline Vs. VLAN enforcement
    my $radius_reply_ref = {};
    my $role = "";
    if ( (!$wasInline || ($wasInline && $vlan != 0) ) && isenabled($self->{_VlanMap})) {
        $radius_reply_ref = {
            'Mikrotik-Wireless-VlanID' => $vlan,
            'Mikrotik-Wireless-VlanIDType' => "0",
        };
    }

    if ( isenabled($self->{_RoleMap}) && $self->supportsRoleBasedEnforcement()) {
        $logger->debug("[$mac] Network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned");
        if ( defined($user_role) && $user_role ne "" ) {
            $role = $self->getRoleByName($user_role);
        }
        if ( defined($role) && $role ne "" ) {
            $radius_reply_ref->{$self->returnRoleAttribute()} = $role;
            $logger->info(
                "[$mac] (".$self->{'_id'}.") Added role $role to the returned RADIUS Access-Accept under attribute " . $self->returnRoleAttribute()
            );
        }
        else {
            $logger->debug("[$mac] (".$self->{'_id'}.") Received undefined role. No Role added to RADIUS Access-Accept");
        }
    }

    $logger->info("[$mac] (".$self->{'_id'}.") Returning ACCEPT with VLAN $vlan and role $role");
    return [$RADIUS::RLM_MODULE_OK, %$radius_reply_ref];
}

=item deauthenticateMacSSH

deauthenticate a MAC address from wireless network

Right now the only way to do it is from the CLI (through SSH).

=cut

sub deauthenticateMacSSH {
    my ( $self, $mac ) = @_;
    my $logger = Log::Log4perl::get_logger( ref($self) );

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't deauthenticate $mac");
        return 1;
    }

    if ( length($mac) != 17 ) {
        $logger->error("MAC format is incorrect ($mac). Should be xx:xx:xx:xx:xx:xx");
        return 1;
    }

    my $ssh;

    my $send_disconnect_to = $self->{'_ip'};
    # but if controllerIp is set, we send there
    if (defined($self->{'_controllerIp'}) && $self->{'_controllerIp'} ne '') {
        $logger->info("controllerIp is set, we will use controller $self->{_controllerIp} to perform deauth");
        $send_disconnect_to = $self->{'_controllerIp'};
    }

    eval {
        $ssh = Net::SSH2->new();
        $ssh->connect($send_disconnect_to);
        $ssh->auth_password($self->{_cliUser},$self->{_cliPwd});
    };

    if ($@) {
        $logger->error("Unable to connect to ".$send_disconnect_to." using ".$self->{_cliTransport}.". Failed with $@");
        return;
    }

    $mac = uc($mac);
    my $command = "/caps-man registration-table remove [/caps-man registration-table find mac-address=$mac]";

    $logger->info("Deauthenticating mac $mac");
    $logger->warn("sending CLI command '$command'");

    my $chan = $ssh->channel();
    $chan->exec($command);
    $ssh->disconnect();

    return 1;
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

