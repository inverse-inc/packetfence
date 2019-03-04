#!/usr/bin/perl

=head1 NAME

t::unittest::switch_groups

=cut

=head1 DESCRIPTION

unit tests for Switch groups

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::node;
use Test::More tests => 8;

#This test will running last
use Test::NoWarnings;

use pf::SwitchFactory;

my $switch;

$switch = pf::SwitchFactory->instantiate("172.16.8.21" );
ok($switch, "Can instantiate a switch member of a group");

is($switch->{_type}, "Meraki::MR",
    "Type is properly inherited from group");

is($switch->{_defaultVlan}, -1,
    "defaultVlan is properly inherited from group");

is($switch->{_customVlan1}, "patate",
    "customVlan1 is properly inherited from default");

$switch = pf::SwitchFactory->instantiate("172.16.8.23");

is($switch->{_type}, "Meraki::MR",
    "Type is properly inherited from group");

is($switch->{_defaultVlan}, 42,
    "defaultVlan is properly defined when set directly in a group member");

$switch = pf::SwitchFactory->instantiate("172.16.3.2");

is($switch->{_customVlan1}, "patate",
    "Inheritance through default switch still works");

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

