#!/usr/bin/perl
=head1 NAME

Group

=cut

=head1 DESCRIPTION

Group

=cut

use strict;
use warnings;

use Test::More tests => 9;

use Test::NoWarnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use setup_test_config;
}

{
    package ConfigStore::HierarchyTest;
    use Moo;
    use pf::ConfigStore;
    use pf::ConfigStore::Hierarchy;

    extends qw(pf::ConfigStore);
    with qw(pf::ConfigStore::Hierarchy);

    sub default_section { undef }

    sub topLevelGroup { "group default" }

    sub _formatGroup {
        return "group ".$_[1];
    }
}

my $config = new_ok("ConfigStore::HierarchyTest",[configFile => './data/hierarchy.conf']);

is_deeply($config->fullConfig("group default"), { param1 => "value1", param2 => "value2" },
    "Default group hierarchy is properly detected");

is_deeply($config->fullConfig("group group1"), { param1 => "group1", param2 => "value2" },
    "group1 hierarchy is properly detected");

is_deeply($config->fullConfig("group group2"), { param1 => "value1", param2 => "group2" },
    "group2 hierarchy is properly detected");

is_deeply($config->fullConfig("element"), { param1 => "value1", param2 => "value2" },
    "element hierarchy is properly detected");

is_deeply($config->fullConfig("element1"), { group => "group1", param1 => "group1", param2 => "value2" },
    "element1 hierarchy is properly detected");

is_deeply($config->fullConfig("element2"), { group => "group2", param1 => "value1", param2 => "group2" },
    "element2 hierarchy is properly detected");

is_deeply($config->fullConfig("element3"), { group => "group1", param1 => "group1", param2 => "element3", param3 => "element3" },
    "element2 hierarchy is properly detected");

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


