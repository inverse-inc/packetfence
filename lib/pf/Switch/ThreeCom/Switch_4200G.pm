package pf::Switch::ThreeCom::Switch_4200G;

=head1 NAME

pf::Switch::ThreeCom::Switch_4200G - Object oriented module to access SNMP
enabled 3COM 4200G Switch

=head1 STATUS

=over

=item Supports

=over

=item 802.1X and MAC Authentication

=item linkUp / linkDown mode

=item port-security (broken! see L</"BUGS AND LIMITATIONS">)

=item VoIP

Voice over IP with 802.1X could work but was not attempted.
Although current limitation regarding 802.1X re-authentication could imply lost calls on VLAN changes.

Voice over IP with MAC Auth works

=back

=back

Developed and tested on Switch 4200G firmware version 3.02.04s56

=head1 BUGS AND LIMITATIONS

=over

=item Unclear NAS-Port to ifIndex translation

This switch's NAS-Port usage is not well documented or easy to guess
so we reversed engineered the translation for the 4200G but it might not apply well to other switches.
If it's your case, please let us know the NAS-Port you obtain in a RADIUS Request and the physical port you are on.
The consequence of a bad translation are that VLAN re-assignment (ie after registration) won't work.

=item Port-Security: security traps not sent under some circumstances

The 4200G exhibit a behavior where secureViolation traps are not sent
if the MAC has already been authorized on another port on the same VLAN.
This tend to happen a lot (when users move on the same switch) for this
reason we recommend not to use this switch in port-security mode.

Firmware version 3.02.00s56 and 3.02.04s56 (latest) were tested and had the problematic behavior.

=item 802.1X Re-Authentication doesn't trigger a DHCP Request from the endpoint

Since this is critical for PacketFence's operation, as a work-around,
we decided to bounce the port which will force the client to re-authenticate and do DHCP.
Because of the port bounce PCs behind IP phones aren't recommended.
This behavior was experienced on a Windows 7 client on the 4200G with the latest firmware.

=item Mac Auth and VoIP

V3.03.02s168p15 has bug when radius returns the vlan corrected in V3.03.02s168p19
OS V3.03.02s168p21 works well, we did lot of tests on it.

=back

=head1 NOTES

=over

=item MAC Authentication and 802.1X behavior

Depending on your needs, you might want to use userlogin-secure-or-mac-ext instead of mac-else-userlogin-secure-ext.
In the former mode a 802.1X failure will leave the port unauthenticated and access will be denied.
In the latter mode, if 802.1X doesn't work then MAC Authentication is attempted.
It's really a matter of choice.

=back

=cut

use strict;
use warnings;

use Net::SNMP;
use POSIX;

use base ('pf::Switch::ThreeCom::SS4500');

use pf::constants;
use pf::config qw(
    $MAC
    $PORT
);
use pf::Switch::constants;

sub description { '3COM 4200G' }

=head1 SUBROUTINES

=over

=item Switch capabilities

=cut

sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
sub supportsRadiusVoip { return $SNMP::TRUE; }
sub supportsLldp { return $TRUE; }

# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT); }

=item NasPortToIfIndex

Translate RADIUS NAS-Port into switch's ifIndex.

=cut

sub NasPortToIfIndex {
    my ($self, $nas_port) = @_;
    my $logger = $self->logger;

    # 4096 NAS-Port slots are reserved per physical ports,
    # I'm assuming that each client will get a +1 so I translate all of them into the same ifIndex
    # Also there's a large offset (16781312), couldn't find where it is coming from...
    my $port = ceil(($nas_port - $THREECOM::NAS_PORT_OFFSET) / $THREECOM::NAS_PORTS_PER_PORT_RANGE);
    if ($port > 0) {

        # TODO we should think about caching or pre-computation here
        my $ifIndex = $self->getIfIndexForThisDot1dBasePort($port);

        # return if defined and an int
        return $ifIndex if (defined($ifIndex) && $ifIndex =~ /^\d+$/);
    }

    # error reporting
    $logger->warn(
        "Unknown NAS-Port format. ifIndex translation could have failed. "
        . "VLAN re-assignment and switch/port accounting will be affected."
    );
    return $nas_port;
}

=item dot1xPortReauthenticate

Because of issues with 802.1X re-auth on these switches, we bounce the port instead.
See in L</"BUGS AND LIMITATIONS">.

=cut

sub dot1xPortReauthenticate {
    my ($self, $ifIndex, $mac) = @_;
    my $logger = $self->logger;

    $logger->warn(
        "Bouncing the port instead of performing 802.1x port re-authentication because of a 4200G bug. "
        . "Your mileage may vary"
    );
    return $self->bouncePort($ifIndex);
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
