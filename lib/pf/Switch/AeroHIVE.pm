package pf::Switch::AeroHIVE;

=head1 NAME

pf::Switch::AeroHIVE

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

use Try::Tiny;

use base ('pf::Switch');

use pf::constants;
use pf::config qw(
    $ROLES_API_LEVEL
    $MAC
    $SSID
);
use pf::file_paths qw($lib_dir);
# RADIUS constants (RADIUS:: namespace)
use pf::radius::constants;
use pf::roles::custom $ROLES_API_LEVEL;
# importing switch constants
use pf::Switch::constants;
use pf::util;

=head1 SUBROUTINES

=over

=cut

# CAPABILITIES
# access technology supported
sub supportsRoleBasedEnforcement { return $TRUE; }
sub supportsWirelessDot1x { return $TRUE; }
sub supportsWirelessMacAuth { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$SSID); }
# locationlog update capabilities
sub supportsRoamingAccounting { return $TRUE };

=item getVersion

obtain image version information from switch

=cut

sub getVersion {
    my ($self) = @_;
    my $oid_AeroHiveSoftwareVersion = '1.3.6.1.2.1.1.1.0'; #
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }

    $logger->trace("SNMP get_request for AeroHiveSoftwareVersion: $oid_AeroHiveSoftwareVersion");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_AeroHiveSoftwareVersion] );
    if (defined($result)) {
        return $result->{$oid_AeroHiveSoftwareVersion};
    }

    # none of the above worked
    $logger->warn("unable to fetch version information");
}

=item parseTrap

This is called when we receive an SNMP-Trap for this device
Old roaming snmp support has been commented if you need to activate it then uncomment it

=cut

sub parseTrap {
    my ( $self, $trapString ) = @_;
    my $trapHashRef;
    my $logger = $self->logger;

#    if ($trapString =~ /\.1\.3\.6\.1\.6\.3\.1\.1\.4\.1\.0 = OID: $AEROHIVE::ahConnectionChangeEvent/ ) {
#        $trapHashRef->{'trapType'} = 'roaming';
#        my @values = split(/\|/, $trapString);
#        my %valeurs;
#        foreach my $val (@values) {
#            my ($oid, $temp) =  split(/ = /, $val);
#            my ($tempo, $value) = split(/: /, $temp);
#            $value =~ s/^\s+|\s+$//g if (defined($value));
#            $valeurs{$oid} = $value;
#        }
#        $trapHashRef->{'trapSSID'} = $valeurs{$AEROHIVE::ahSSID};
#        $trapHashRef->{'trapSSID'} =~ s/"//g;
#        $trapHashRef->{'trapIfIndex'} = $valeurs{$AEROHIVE::ahIfIndex};
#        $trapHashRef->{'trapVlan'} = $valeurs{$AEROHIVE::ahClientVLAN};
#        $trapHashRef->{'trapMac'} = $valeurs{$AEROHIVE::ahRemoteId};
#        $trapHashRef->{'trapClientUserName'} = $valeurs{$AEROHIVE::ahClientUserName};
#        $trapHashRef->{'trapConnectionType'} = $WIRELESS_MAC_AUTH;
#        if ($valeurs{$AEROHIVE::ahClientAuthMethod} eq '6' || $valeurs{$AEROHIVE::ahClientAuthMethod} eq '7') {
#            $trapHashRef->{'trapConnectionType'} = $WIRELESS_802_1X;
#        }
#    }
#    else {
#        $logger->debug("trap currently not handled");
#        $trapHashRef->{'trapType'} = 'unknown';
#    }
#    return $trapHashRef;
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
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("(".$self->{'_id'}.") not in production mode... we won't perform deauthentication");
        return 1;
    }

    $logger->debug("deauthenticate using RADIUS Disconnect-Request deauth method");
    return $self->radiusDisconnect($mac);
}

=item _deauthenticateMacTelnet

** DEPRECATED

deauthenticate a MAC address from wireless network

Right now te only way to do it is from the CLi (through Telnet or SSH).

Warning: this code doesn't support elevating to privileged mode. See #900 and #1370.

=cut

sub _deauthenticateMacTelnet {
    my ( $self, $mac ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("(".$self->{'_id'}.") not in production mode ... we won't deauthenticate");
        return 1;
    }

    if ( length($mac) != 17 ) {
        $logger->error("MAC format is incorrect ($mac). Should be xx:xx:xx:xx:xx:xx");
        return 1;
    }

    my $session;
    eval {
        require Net::Appliance::Session;
        $session = Net::Appliance::Session->new(
            Host      => $self->{_ip},
            Timeout   => 5,
            Transport => $self->{_cliTransport},
            Platform => 'HiveOS',
            Source   => $lib_dir.'/pf/Switch/AeroHIVE/nas-pb.yml'
        );
        $session->connect(
            Name     => $self->{_cliUser},
            Password => $self->{_cliPwd}
        );
    };

    if ($@) {
        $logger->error("Unable to connect to ".$self->{'_ip'}." using ".$self->{_cliTransport}.". Failed with $@");
        return;
    }

    # if $session->begin_configure() does not work, use the following command:
    my $command = "clear auth station mac $mac";

    $logger->info("Deauthenticating mac");
    $logger->trace("sending CLI command '$command'");
    my @output;
    $session->in_privileged_mode(1);
    eval {
        @output = $session->cmd(String => $command, Timeout => '10');
    };
    $session->in_privileged_mode(0);
    if ($@) {
        $logger->error("Unable to deauthenticate: $@");
        $session->close();
        return;
    }
    $session->close();
    return 1;
}

=item returnRadiusAccessAccept

Overloading L<pf::Switch>'s implementation because AeroHIVE doesn't support
assigning VLANs and Roles at the same time.

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    my $radius_reply_ref = {};
    my $status;
    # should this node be kicked out?
    my $kick = $self->handleRadiusDeny($args);
    return $kick if (defined($kick));

    $logger->debug("Network device (".$self->{'_id'}.") supports roles. Evaluating role to be returned.");
    if ( isenabled($self->{_RoleMap}) && $self->supportsRoleBasedEnforcement()) {
        my $role = $self->getRoleByName($args->{'user_role'});

        # Roles are configured and the user should have one
        if (defined($role) && $role ne ""  && isenabled($self->{_RoleMap})) {
            $radius_reply_ref = {
                'Tunnel-Medium-Type' => $RADIUS::IP,
                'Tunnel-Type' => $RADIUS::GRE,
                'Tunnel-Private-Group-ID' => $role,
            };
        }

        $logger->info("(".$self->{'_id'}.") Returning ACCEPT with Role: $role");

    }

    # if Roles aren't configured, return VLAN information
    if (isenabled($self->{_VlanMap}) && defined($args->{'vlan'})) {
        $radius_reply_ref = {
             %$radius_reply_ref,
            'Tunnel-Medium-Type' => $RADIUS::ETHERNET,
            'Tunnel-Type' => $RADIUS::VLAN,
            'Tunnel-Private-Group-ID' => $args->{'vlan'},
        };

        $logger->info("Returning ACCEPT with VLAN: $args->{'vlan'}");
    }

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];

}

=item returnRoleAttribute

AeroHive assigns roles differently, see it's implementation of returnRadiusAccessAccept.

This stub is here otherwise roles support tests fails since we expect an returnRoleAttribute implementation.

=cut

sub returnRoleAttribute {
    my ($self) = @_;
    return;
}


=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::RADIUS;
    my %tech = (
        $SNMP::RADIUS => 'deauthenticateMacDefault',
        $SNMP::TELNET  => '_deauthenticateMacTelnet',
    );

    if (!defined($method) || !defined($tech{$method})) {
        $method = $default;
    }
    return $method,$tech{$method};
}


=back

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
