#!/usr/bin/perl

=head1 NAME

N1500

=head1 DESCRIPTION

unit test for N1500

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 5;
use pf::Switch::Dell::N1500;

#This test will running last
use Test::NoWarnings;

my $switch = pf::Switch::Dell::N1500->new({});

ok(
    $switch->getBitAtPosition("0x0024", $SNMP::LLDP::TELEPHONE),
    "$SNMP::LLDP::TELEPHONE is found in bit table"
);

ok(
    $switch->getBitAtPosition(pack("B*", "0000000000100100"), $SNMP::LLDP::TELEPHONE),
    "$SNMP::LLDP::TELEPHONE is found in bit table"
);

# A role ACL keeps its direction separator, so the reply sends it as an inacl attribute
is(
    $switch->acl_chewer("permit ip any host 192.0.2.10", 'testrole'),
    "in|permit ip any host 192.0.2.10 \n",
    "a role ACL line is chewed with its in| direction"
);

is(
    ($switch->returnAccessListAttribute(101, "in|permit ip any host 192.0.2.10 "))[1],
    "ip:inacl#101=permit ip any host 192.0.2.10 ",
    "a chewed role ACL line is sent as ip:inacl"
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
