package pf::Switch::Meru;

=head1 NAME

pf::Switch::Meru

=head1 SYNOPSIS

Module to manage Meru controllers

=head1 STATUS

Tested against MeruOS version 3.6.1-67

=over

=item Supports

=over

=item Deauthentication with CLI (Telnet/SSH)

=item Roles-assignment through RADIUS

=back

=back

=head1 BUGS AND LIMITATIONS

=over

=item CLI deauthentication

De-authentication of a Wireless user is based on CLI access (Telnet or SSH).
This is a vendor issue and it might be fixed in newer firmware versions.

=item Per SSID VLAN Assignment on unencrypted network not supported

The vendor doesn't include the SSID in their RADIUS-Request when on MAC Authentication.
VLAN assignment per SSID is not possible.
This is a vendor issue and might be fixed in newer firmware versions.

=item Caching problems on secure connections

Performing a de-authentication does not clear the key cache.
Meaning that on reconnection the device's authorization is served straight from the cache
instead of creating a new RADIUS query.
This defeats the reason why we perform de-authentication (to change VLAN or deny access).

A client-side workaround exists: disable the PMK Caching on the client.
However this could (and should in our opinion) be fixed by the vendor.

We made some progress about this lately.  In fact, for the 4.0 version tree, you need
to get version 4.0-160 in order to disable the PMK caching at the AP level.  For the
5.0 version tree, all versions including 5.0-87 are impacted.  Vendor is saying that
in the 5.1 version, PMK will be disabled by default.  To be confirmed.

=item Be careful with Roles access control support (Meru's firewall rules)

Once written these are enforced automatically on the controller's primary
ethernet interface.

=back

=cut

use strict;
use warnings;

use base ('pf::Switch');

use pf::constants;
use pf::config qw(
    $MAC
    $SSID
);
use pf::file_paths qw($lib_dir);
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

=item getVersion

obtain image version information from switch

=cut

sub getVersion {
    my ($self) = @_;
    my $oid_mwWncVarsSoftwareVersion = '1.3.6.1.4.1.15983.1.1.4.1.1.27'; # from meru-wlan
    my $logger = $self->logger;
    if ( !$self->connectRead() ) {
        return '';
    }

    # mwWncVarsSoftwareVersion sample output:
    # 3.6.1-67

    # first trying with a .0
    $logger->trace("SNMP get_request for mwWncVarsSoftwareVersion: $oid_mwWncVarsSoftwareVersion.0");
    my $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_mwWncVarsSoftwareVersion.".0"] );
    if (defined($result)) {
        return $result->{$oid_mwWncVarsSoftwareVersion.".0"};
    }

    # then trying straight
    $logger->trace("SNMP get_request for mwWncVarsSoftwareVersion: $oid_mwWncVarsSoftwareVersion");
    $result = $self->{_sessionRead}->get_request( -varbindlist => [$oid_mwWncVarsSoftwareVersion] );
    if (defined($result)) {
        return $result->{$oid_mwWncVarsSoftwareVersion};
    }

    # none of the above worked
    $logger->warn("unable to fetch version information");
}

=item deauthenticateMacDefault

deauthenticate a MAC address from wireless network

Right now te only way to do it is from the CLi (through Telnet or SSH).

Warning: this code doesn't support elevating to privileged mode. See #900 and #1370.

=cut

sub deauthenticateMacDefault {
    my ( $self, $mac ) = @_;
    my $logger = $self->logger;

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode ... we won't deauthenticate $mac");
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
            Platform => 'MeruOS',
            Source   => $lib_dir.'/pf/Switch/Meru/nas-pb.yml'
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

    # Session not already privileged are not supported at this point. See #1370
    #if (!$session->in_privileged_mode()) {
    #    if (!$session->enable($self->{_cliEnablePwd})) {
    #        $logger->error("Cannot get into privileged mode on ".$self->{'ip'}.
    #                       ". Are you sure you provided enable password in configuration?");
    #        $session->close();
    #        return;
    #    }
    #}

    # if $session->begin_configure() does not work, use the following command:
    # my $command = "configure terminal\nno station $mac\n";
    my $command = "no station $mac";

    $logger->info("Deauthenticating mac $mac");
    $logger->trace("sending CLI command '$command'");
    my @output;
    $session->in_privileged_mode(1);
    eval {
        $session->begin_configure();
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

=item returnRoleAttribute

Meru uses the standard Filter-Id parameter.

=cut

sub returnRoleAttribute {
    my ($self) = @_;

    return 'Filter-Id';
}

=item deauthTechniques

Return the reference to the deauth technique or the default deauth technique.

=cut

sub deauthTechniques {
    my ($self, $method) = @_;
    my $logger = $self->logger;
    my $default = $SNMP::TELNET;
    my %tech = (
        $SNMP::TELNET => 'deauthenticateMacDefault',
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
