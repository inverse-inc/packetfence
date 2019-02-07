package pf::Switch::HP::E5500G;

=head1 NAME

pf::Switch::HP::E4800G

-head1 DESCRIPTION

A copy of the 3COM E5500G Switch module because HP bought 3Com and is selling re-branded 3Com

=head1 STATUS

=over

=item Supports

=over

=item 802.1X and MAC Authentication

=item linkUp / linkDown mode

=item port-security (untested)

=item VoIP

Voice over IP with MAC Auth / 802.1X could work but was not attempted.
Although current limitation regarding 802.1X re-authentication could imply lost calls on VLAN changes.

=back

=back

802.1X and MAC-Authentication confirmed to work with firmware V3.03.02s168p07.

Tested by the community.

=head1 BUGS AND LIMITATIONS

=over

=item Stacked switches not tested

We never tested these switches in a stacked configuration.
It might work out of the box or the module might need adjustments.

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

This behavior has not been confirmed or denied for this model.

=item 802.1X Re-Authentication doesn't trigger a DHCP Request from the endpoint

Since this is critical for PacketFence's operation, as a work-around,
we decided to bounce the port which will force the client to re-authenticate and do DHCP.
Because of the port bounce PCs behind IP phones aren't recommended.
This behavior was experienced on a Windows 7 client on the 4200G with the latest firmware.

This behavior has not been confirmed or denied for this model.

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

use base ('pf::Switch::ThreeCom::Switch_4200G');

sub description { 'HP E5500G (3Com)' }

=head1 SUBROUTINES

=over

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
