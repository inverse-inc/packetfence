#!/usr/bin/perl

=head1 NAME

radius-hook.pl - taps directly into pf::radius for profiling / debugging

=cut

use strict;
use warnings;
use Data::Dumper;

use constant INSTALL_DIR => '/usr/local/pf';
use lib INSTALL_DIR . "/lib";

use pf::radius::custom;

# perl -d:SmallProf variables 
%DB::packages = ( 'main' => 1, 'pf::radius' => 1, 'pf::SwitchFactory' => 1); 
$DB::drop_zeros = 1;

my $radius = new pf::radius::custom();
# unregistered
#print Dumper($radius->authorize(
#    "Wireless-802.11", "192.168.1.60", 0, "aa:bb:cc:dd:ee:ff", 12345, "aabbccddeeff", "Inverse-Invite")
#);

# registered
print Dumper($radius->authorize(
    "Wireless-802.11", "192.168.1.60", 0, "00:13:ce:58:42:e2", 12345, "aabbccddeeff", "Inverse-Invite")
);

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
