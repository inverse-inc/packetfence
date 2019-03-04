#!/usr/bin/perl

=head1 NAME

assign-owner.pl

=head1 SYNOPSIS

./assign-owner.pl <MAC address> <pid>

=head1 DESCRIPTION

Assign an owner to a node by its MAC address.
Will create the MAC address if it doesn't already exist.
Will create the owner if it doesn't already exist.

=cut


use strict;
use warnings;

use lib '/usr/local/pf/lib';

use Pod::Usage;
use pf::util;
use pf::log;
use pf::node;
use pf::person;

use Data::Dumper;
get_logger->info(Dumper(@ARGV));

my $mac = clean_mac($ARGV[0]);
my $owner = $ARGV[1];

if(!$mac) {
    print STDERR "Missing or invalid MAC address\n";
    pod2usage(1);
}

if(!$owner) {
    print STDERR "Missing owner\n";
    pod2usage(1);
}

if(!person_exist($owner)) {
    person_add($owner);
}

node_modify($mac, pid => $owner);

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

