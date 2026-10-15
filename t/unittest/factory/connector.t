#!/usr/bin/perl

=head1 NAME

connector

=head1 DESCRIPTION

unit test for pf::factory::connector

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 7;
use Test::MockModule;

#This test will running last
use Test::NoWarnings;

use pf::factory::connector;

my $dns_answer;
my $mock = Test::MockModule->new('pf::factory::connector');
$mock->mock('resolve_dns_with_custom_resolver', sub { @$dns_answer });

is(pf::factory::connector->resolve('10.0.0.16'), '10.0.0.16', "A bare IP is used as is");

$dns_answer = [['10.0.0.16'], undef];
is(pf::factory::connector->resolve('ad.example.com'), '10.0.0.16', "A hostname outside of the connector networks resolves to its IP");

$dns_answer = [['10.0.0.16', '12.36.24.5'], undef];
is(pf::factory::connector->resolve('ad.example.com'), '12.36.24.5', "The IP part of a connector network is preferred");

$dns_answer = [undef, "NXDOMAIN"];
is(pf::factory::connector->resolve('ad.example.com'), undef, "An unresolvable hostname returns undef");

is(pf::factory::connector->for_ip('12.36.24.5')->{id}, 'test_networks', "IP in a connector network uses that connector");
is(pf::factory::connector->for_ip('10.0.0.16')->{id}, 'local_connector', "IP outside of the connector networks uses the local connector");

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
