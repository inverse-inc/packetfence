#!/usr/bin/perl

=head1 NAME

to-7.0-roles-conf.pl

=cut

=head1 DESCRIPTION

Migrate the roles that are in the database into roles.conf

=cut

use lib '/usr/local/pf/lib';

use pf::nodecategory;
use pf::ConfigStore::Roles;
use pf::util;

run_as_pf();

my @roles = nodecategory_view_all();

my $cs = pf::ConfigStore::Roles->new();

foreach my $role (@roles) {
    delete $role->{category_id};
    my $name = delete $role->{name};
    $cs->update_or_create($name, $role);
}

$cs->commit();

print "All done. The roles that were in the table nodecategory should now appear in /usr/local/pf/conf/roles.conf\n";

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

