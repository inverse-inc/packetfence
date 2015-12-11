#!/usr/bin/perl
=head1 NAME

Group

=cut

=head1 DESCRIPTION

Group

=cut

use strict;
use warnings;

use Test::More tests => 16;

use Test::NoWarnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use PfFilePaths;
}


use_ok("ConfigStore::HierarchyTest");


my $config = new_ok("pf::ConfigStore::HierarchyTest",[configFile => './data/hierarchy.conf']);

is_deeply($config->fullConfig("default"), {param1 => "value1", param2 => "value2"});

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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


