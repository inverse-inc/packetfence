package pf::Switch::Meraki::MR_v2;

=head1 NAME

pf::Switch::Meraki::MR_v2

=head1 SYNOPSIS

Implement object oriented module to interact with Meraki MR (v2) network equipment

=head1 STATUS

Developed and tested on a MR12 access point

=cut

use strict;
use warnings;

use base ('pf::Switch::Cisco::WLC');

use Net::SNMP;
use Try::Tiny;
use pf::constants;
use pf::util;
use pf::node;
use pf::util::radius qw(perform_coa);

sub description { 'Meraki cloud controller V2' }

=head2 returnRoleAttribute

What RADIUS Attribute (usually VSA) should the role returned into.

=cut

sub returnRoleAttribute {
    return 'Airespace-ACL-Name';
}

=head2 addDPSK

Add the DPSK to a RADIUS reply

=cut

sub addDPSK {
    my ($self, $args, $radius_reply_ref, $av_pairs) = @_;
    if ($args->{profile}->dpskEnabled()) {
        if (defined($args->{owner}->{psk})) {
            $radius_reply_ref->{'Tunnel-Password'} = $args->{owner}->{psk};
        } else {
            $radius_reply_ref->{'Tunnel-Password'} = $args->{profile}->{_default_psk_key};
        }
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
