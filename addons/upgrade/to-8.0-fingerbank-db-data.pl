#!/usr/bin/perl

=head1 NAME

to-8.0-fingerbank-db-data.pl

=cut

=head1 DESCRIPTION

Since the device names have changed in Fingerbank, we rename the most popular ones to their new name and clear out the other old device names so they get repopulated

=cut

use strict;
use warnings;
use lib '/usr/local/pf/lib';

use pf::db;

my %remap = (
    "Gaming Consoles" => "Gaming Console",
    "Macintosh" => "Mac OS X or macOS",
    "Linux" => "Linux OS",
    "Printers/Scanners" => "Printer or Scanner",
    "Projectors" => "Projector",
    "Routers and APs" => "Router, Access Point or Femtocell",
    "Smartphones/PDAs/Tablets" => "Phone, Tablet or Wearable",
    "Storage Devices" => "Storage Device",
    "Switches" => "Switch",
    "Thin Clients" => "Thin Client",
    "VoIP Phones/Adapters" => "VoIP Device",
    "Windows" => "Windows OS",
);

while(my ($old, $new) = each(%remap)) {
    my $query = "UPDATE node set device_class='$new', device_type='$new' where device_class='$old';";
    get_db_handle->do($query)
}

my @conds = map { "device_class!='$_'" } values(%remap);
my $condition = join(" AND ", @conds);

get_db_handle->do("UPDATE node set device_class=NULL, device_type=NULL where $condition");

print "Completed migration of the Fingerbank device names in the node table \n";

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
