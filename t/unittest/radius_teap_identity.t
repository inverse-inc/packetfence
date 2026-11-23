#!/usr/bin/perl

=head1 NAME

radius_teap_identity

=cut

=head1 DESCRIPTION

unit test for pf::radius::_teap_identity, the username used for the outer
request of an EAP-TEAP authentication

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

use Test::More tests => 7;
use pf::radius;

#This test will running last
use Test::NoWarnings;

sub identity { [ pf::radius::_teap_identity(@_) ] }

is_deeply(identity('anonymous', 'anonymous', 'null', undef, undef),
    ['anonymous', 'anonymous', 'null'], 'inner round (undef): unchanged');

is_deeply(identity('anonymous', 'anonymous', 'null', '', ''),
    ['anonymous', 'anonymous', 'null'], 'outer round without TEAP identity: unchanged');

is_deeply(identity('anonymous', 'anonymous', 'null', 'packetfence', 'host/testpc.example.lan'),
    ['packetfence', 'packetfence', 'null'], 'user identity wins over the machine identity');

is_deeply(identity('anonymous', 'anonymous', 'null', '', 'host/testpc.example.lan'),
    ['host/testpc.example.lan', 'host/testpc.example.lan', 'null'], 'machine-only authentication uses the machine identity');

is_deeply(identity('anonymous@example.lan', 'anonymous', 'example.lan', 'EXAMPLE\\packetfence', ''),
    ['EXAMPLE\\packetfence', 'packetfence', 'EXAMPLE'], 'domain\\user is stripped and its realm used');

is_deeply(identity('anonymous@example.lan', 'anonymous', 'example.lan', 'packetfence', ''),
    ['packetfence', 'packetfence', 'example.lan'], 'no realm in the inner identity keeps the outer realm');

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
