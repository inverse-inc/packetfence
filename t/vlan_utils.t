#!/usr/bin/perl

=head1 NAME

example pf test

=cut

=head1 DESCRIPTION

example pf test script

=cut

use strict;
use warnings;
#
use lib qw(/root/code/packetfence/lib );
use pf::role;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t /root/code/packetfence/t);

    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 6;

#This test will running last
#use Test::NoWarnings;
my $mac = '00:12:f0:13:32:BA';

my $node_info = {
    bypass_vlan => 1,
    bypass_role => "default"
};

is( pf::role::_check_bypass($mac, $node_info),
    ( 1, "default" ),
    "check_bypass returns the bypass_vlan and bypass_role"
);

$node_info = {
    bypass_role => "default"
};

is( pf::role::_check_bypass($mac, $node_info),
    ( undef, "default" ),
    "check_bypass returns the undef bypass_vlan and bypass_role"
);

$node_info = {
    bypass_vlan => 1,
};

is( pf::role::_check_bypass($mac, $node_info),
    ( 1, undef ),
    "check_bypass returns the bypass_vlan and undef bypass_role"
);

$node_info = {
};

is( pf::role::_check_bypass($mac, $node_info),
    ( undef, undef ),
    "check_bypass returns the undef bypass_vlan and undef bypass_role"
);

undef $node_info; 
is( pf::role::_check_bypass($mac, $node_info),
    ( undef, undef ),
    "check_bypass returns the undef bypass_vlan and undef bypass_role when passed undef node_info"
);

undef $mac;
is( pf::role::_check_bypass($mac, $node_info),
    ( undef, undef ),
    "check_bypass returns the undef bypass_vlan and undef bypass_role when passed undef mac"
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

1;
