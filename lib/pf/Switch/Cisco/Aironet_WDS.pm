package pf::Switch::Cisco::Aironet_WDS;
=head1 NAME

pf::Switch::Cisco::Aironet_WDS - Object oriented module to parse SNMP traps
and manage Cisco Aironet configured in Wireless Domain Services (WDS) mode.

=head1 STATUS

This module implements some changes on top of L<pf::Switch::Cisco::WLC>.
You should also consult the documentation over there if you experience issues.

=over

=item Supports

Deauthentication with RADIUS Disconnect (RFC3576)

=back

Tested on an Aironet WDS on IOS 12.3.8JEC3

=head1 BUGS AND LIMITATIONS

=over

=item deauthentication requires SSH access

Even though we perform the deauthentication with RFC3576 through Packet of
Disconnect (PoD). SSH access is still required.

Due to a Cisco issue, deauthentication attempts made directly to the
WDS node, even though accepted, do not fully deauthenticate the client. It
feels like the crypto caches aren't properly invalidated which cause
subsequent re-association from the client never to trigger AAA.

As a work-around, we connect to the WDS to obtain the current Access-Point
where the MAC is located (with SSH) and then issue a PoD directly to the AP.

Several improvements could be made by Cisco regarding this issue so a close
look at their next IOS releases notes is in order.

For more information see: https://supportforums.cisco.com/thread/2148888

=back

=cut

use strict;
use warnings;

use pf::log;
use Net::SNMP;
use Try::Tiny;

use base ('pf::Switch::Cisco::WLC');

use pf::util qw(format_mac_as_cisco);

=head1 METHODS

=over

=item description

=cut

sub description { 'Cisco Aironet (WDS)' }

=item deauthenticateMacDefault

De-authenticate a MAC address from wireless network (including 802.1x).

Diverges from L<pf::Switch::Cisco::WLC> in the following aspects:

=over

=item No Service-Type

=item Called-Station-Id in the Cisco format (aabb.ccdd.eeff)

=back

=cut

# The Service-Type entry was causing the WDS enabled Aironet to crash (IOS 12.3.8JEC3)
sub deauthenticateMacDefault {
    my ( $self, $mac, $is_dot1x ) = @_;
    my $logger = get_logger();

    if ( !$self->isProductionMode() ) {
        $logger->info("not in production mode... we won't perform deauthentication");
        return 1;
    }

    # we must perform the deauth against the AP that the client is currently connected to
    my $ap_ip = $self->getCurrentApFromMac($mac);
    if (!defined($ap_ip)) {
        $logger->error("deauthentication impossible, could not find AP for MAC $mac");
        return;
    }

    $logger->debug("deauthenticate $mac on AP $ap_ip using RADIUS Disconnect-Request deauth method");
    my $mac_for_deauth = format_mac_as_cisco($mac);
    return $self->radiusDisconnect($mac, {
        'NAS-IP-Address' => $ap_ip,
        'Calling-Station-Id' => $mac_for_deauth,
    });
}

=item getCurrentApFromMac

Warning: this method should _never_ be called in a thread.
Net::Appliance::Session is L<not thread safe|http://www.cpanforum.com/threads/6909/>.
Experienced when using SSH.

Warning: this code doesn't support elevating to privileged mode. See #900 and #1370.

=cut

sub getCurrentApFromMac {
    my ( $self, $mac ) = @_;
    my $logger = get_logger();

    my $session;
    try {
        require Net::Appliance::Session;
        $session = Net::Appliance::Session->new(
            Host => $self->{_ip},
            Timeout => 25, # apparently these things are very slow
            Transport => $self->{_cliTransport},
        );
        $session->connect(
            Name     => $self->{_cliUser},
            Password => $self->{_cliPwd}
        );
    }
    catch {
        chomp($_);
        $logger->warn("Unable to connect to ".$self->{'_ip'}." using ".$self->{_cliTransport}.". Failed with $_");
        $session = undef;
    };
    return if (!defined($session));

    # preparing parameters
    my $mac_for_cmd = format_mac_as_cisco($mac);

    # running the command
    my $command = "show wlccp wds mn detail mac-address $mac_for_cmd";
    $logger->debug("sending CLI command '$command'");
    my @output;
    try { @output = $session->cmd(String => $command, Timeout => '15'); } # apparently these things are very slow
    catch {
        chomp($_);
        $logger->warn("Error with command $command on ".$self->{'_ip'}.". Failed with $_");
        $session->close();
    };
    return if (!@output);

    # interpreting the result
    # Here's a sample of the results
    #    > show wlccp wds mn detail mac-address 0021.9105.FF11
    #    MAC: 0021.9105.ff11,  IP-ADDR: 192.168.0.181,  State: REGISTERED
    #    Cur-AP: 0018.19bd.ba13, 10.11.61.252
    #    BSS: 0018.7331.09c0, SSID: WIFIBC1
    #    Vlan: 192
    #    Ntwrk-ID Assigned by AAA:   -
    #    Key Mgmt: None,  Authentication: EAP
    #    Posture Token:
    #    Up-time: 00:25:30, Lifetime: 214
    my $cur_ap_ip;
    foreach my $line (@output) {
        if ($line =~ /^Cur-AP: [0-9a-f]{4}\.[0-9a-f]{4}\.[0-9a-f]{4}, ([0-9.]*)/) {
            $cur_ap_ip = $1;
            last;
        }
    }

    if (defined($cur_ap_ip)) {
        $session->close();
        return $cur_ap_ip;
    }
    elsif ($output[0] =~ /^\s+$/) {
        $logger->warn("MAC $mac not found on any Access-Point in the WDS. This could be normal if user disconnected.");
        $session->close();
        return;
    }

    # otherwise report an error
    $logger->warn("Error with command $command on ".$self->{'_ip'}.". Failed with ".join(@output));
    $session->close();
    return;
}

=item extractSsid

Overriding default extractSsid because on Aironet AP SSID is in the Cisco-AVPair VSA.

=cut

# Same as in pf::Switch::Cisco::Aironet. Please keep both in sync. Once Moose push in a role.
sub extractSsid {
    my ($self, $radius_request) = @_;
    my $logger = $self->logger;

    if (defined($radius_request->{'Cisco-AVPair'})) {
        if (ref($radius_request->{'Cisco-AVPair'}) eq 'ARRAY') {
            foreach my $ciscoAVPair (@{$radius_request->{'Cisco-AVPair'}}) {
                $logger->trace("Cisco-AVPair: ".$ciscoAVPair);

                if ($ciscoAVPair =~ /^ssid=(.*)$/) { # ex: Cisco-AVPair = "ssid=PacketFence-Secure"
                    return $1;
                } else {
                    $logger->info("Unable to extract SSID of Cisco-AVPair: ".$ciscoAVPair);
                }
            }
        } else {
            if ($radius_request->{'Cisco-AVPair'} =~ /^ssid=(.*)$/) { # ex: Cisco-AVPair = "ssid=PacketFence-Secure"
                return $1;
            } else {
                $logger->info("Unable to extract SSID of Cisco-AVPair: ".$radius_request->{'Cisco-AVPair'});

            }
        }
    }

    $logger->warn(
        "Unable to extract SSID for module " . ref($self) . ". SSID-based VLAN assignments won't work. "
        . "Make sure you enable Vendor Specific Attributes (VSA) on the AP if you want them to work."
    );
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
