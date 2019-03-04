#!/usr/bin/perl

=head1 NAME

to-3.0-networks.conf.pl - 3.0 upgrade script for conf/networks.conf

=head1 USAGE

Basically: 

  addons/upgrade/to-3.0-networks.conf.pl < conf/networks.conf > networks.conf.new

Then look at networks.conf.new and if it's ok, replace your conf/networks.conf with it.

=head1 DESCRIPTION

Here's what this script fixes:

=over

=item type= names deprecation

isolation is now vlan-isolation. 
registration is now vlan-registration.

=item pf_gateway deprecated

Parameter now called next_hop.

=back

=cut

use strict;
use warnings;

while (<>) {

    if (/^type=isolation$/i) {
        print "type=vlan-isolation\n";

    } elsif (/^type=registration$/i) {
        print "type=vlan-registration\n";

    } elsif (/^pf_gateway=(.*)$/i) {
        print "next_hop=$1\n";

    } else {
        print;
    }
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

