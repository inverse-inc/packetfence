#!/usr/bin/perl

=head1 NAME

generatesyslogconfig

=head1 DESCRIPTION

unit test for pf::cmd::pf::generatesyslogconfig

=cut

use strict;
use warnings;
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 5;
use pf::cmd::pf::generatesyslogconfig;

#This test will running last
use Test::NoWarnings;

is(
    pf::cmd::pf::generatesyslogconfig::server_action({ proto => 'udp', host => '10.0.0.1', port => 514 }, 'packetfence.log'),
    '@10.0.0.1:514;PacketFenceForwardFormat',
    'UDP forwarding uses the PacketFence template'
);

is(
    pf::cmd::pf::generatesyslogconfig::server_action({ proto => 'tcp', host => '10.0.0.1', port => 514 }, 'packetfence.log'),
    '@@10.0.0.1:514;PacketFenceForwardFormat',
    'TCP forwarding uses the PacketFence template'
);

like($pf::cmd::pf::generatesyslogconfig::FORWARD_TEMPLATE, qr/name="PacketFenceForwardFormat"/, 'template is named');
unlike($pf::cmd::pf::generatesyslogconfig::FORWARD_TEMPLATE, qr/syslogtag:1:32/, 'the tag is not truncated to 32 characters');

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

