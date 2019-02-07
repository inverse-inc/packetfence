#!/usr/bin/perl

=head1 NAME

to-3.0-pf.conf.pl - 3.0 upgrade script for conf/pf.conf

=head1 USAGE

Basically: 

  addons/upgrade/to-3.0-pf.conf.pl < conf/pf.conf > pf.conf.new

Then look at pf.conf.new and if it's ok, replace your conf/pf.conf with it.

=head1 DESCRIPTION

Here's what this script fixes:

=over

=item mode vlan removal

No longer required.

=item dhcpd / named changes

They changed section and they default to enabled so if we see them as enabled we simply get rid of the entries.

=item scan.live_tids dropped

We just drop it.

=item trapping.testing

We just drop it.

=back

=cut

use strict;
use warnings;

while (<>) {

    # removing
    next if (/^mode=vlan\s*$/i);
    next if (/^named=\s*enabled\s*$/i);
    next if (/^dhcpd=\s*enabled\s*$/i);
    next if (/^live_tids=.*$/i);
    next if (/^testing=.*$/i);

    # if we didn't skip, we keep
    print;
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

