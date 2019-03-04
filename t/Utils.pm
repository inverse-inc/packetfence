package Utils;

=head1 NAME

Utils -

=head1 DESCRIPTION

Utils

=cut

use strict;
use warnings;
use pf::util;
use pf::node;

sub test_mac {
    my $mac = random_mac();
    while (node_exist($mac)) {
        $mac = random_mac();
    }

    return $mac;
}

sub random_mac {
    return clean_mac(unpack("h*", pack("S", int(rand(65536)))) . unpack("h*", pack("N", $$ + rand(2147352576))));
}

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
