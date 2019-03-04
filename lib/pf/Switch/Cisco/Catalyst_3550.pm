package pf::Switch::Cisco::Catalyst_3550;

=head1 NAME

pf::Switch::Cisco::Catalyst_3550 - Object oriented module to access and configure Cisco Catalyst 3550 switches

=head1 STATUS

This module is currently only a placeholder, see pf::Switch::Cisco::Catalyst_2960.

IOS 12.2(44)SE6 is known to work.

=head1 BUGS AND LIMITATIONS

Because a lot of code is shared with the 2960 make sure to check the BUGS AND LIMITATIONS section of 
L<pf::Switch::Cisco::Catalyst_2960> also.

=over 

=item Port-Security + Voice over IP (VoIP): IOS 12.2(25r) disappearing config

For some reason when securing a MAC address the switch loses an important portion of its config.
This is a Cisco bug, nothing much we can do. Don't use this IOS for VoIP.
See issue #1020 for details.

=item Port-Security problematic firmwares

Known issues with IOS 12.2(35)SE5

=item ifIndex inconsistencies

IfIndex on this platform is not the same as port # or dot1d port.

=back

=cut

use strict;
use warnings;
use Net::SNMP;

use base ('pf::Switch::Cisco::Catalyst_2960');

sub description { 'Cisco Catalyst 3550' }

=head1 SUBROUTINES

=over

=item NasPortToIfIndex

Translate RADIUS NAS-Port into switch's ifIndex.
This switch's NAS-Port behavior is different than the 2960.

We considered changing the dependency chain to the 2950 but we think we 
have less chances of breaking things if we just do the proper translation 
here because we would have heard if port-security was broken anyway. That 
said, if you hear about MAC-Auth / 802.1x regressions consider making this 
method do per-IOS translations.

=cut

sub NasPortToIfIndex {
    my ($self, $NAS_port) = @_;
    my $logger = $self->logger;

    # 50017 is ifIndex 17
    if ($NAS_port =~ s/^500//) {
        return $NAS_port;
    } else {
        $logger->warn("Unknown NAS-Port format. ifIndex translation could have failed. "
            ."VLAN re-assignment and switch/port accounting will be affected.");
    }
    return $NAS_port;
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
