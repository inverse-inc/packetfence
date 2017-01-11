=head1 NAME

util::dns test

=cut

=head1 DESCRIPTION

util::dns test

=cut

use strict;
use warnings;
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::Deep;
use Test::More tests => 29;
#This test will running last
use Test::NoWarnings;
use Socket;

use pf::constants;
use_ok("pf::util::dns");

my ($match, $ports);

($match, $ports) = pf::util::dns::matches_passthrough();
is($match, $FALSE, "undef domain will not match passthroughs");

($match, $ports) = pf::util::dns::matches_passthrough("zammitcorp.com");
is($match, $TRUE, "valid passthrough domain will match passthroughs");
cmp_deeply(['tcp:80', 'tcp:443', 'tcp:22'], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("zammitcorp.io");
is($match, $FALSE, "invalid passthrough domain will not match passthroughs");
cmp_deeply([], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("dinde.ca");
is($match, $TRUE, "valid passthrough domain that has a port will match passthroughs");
cmp_deeply(['tcp:2828'], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("dinde.io");
is($match, $FALSE, "invalid passthrough domain that has a port will not match passthroughs");
cmp_deeply([], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("some.sub.domain.tld");
is($match, $TRUE, "valid passthrough sub-domain will match TLD passthroughs");
cmp_deeply(['tcp:80', 'tcp:443'], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("some.sub.domain.tld.com");
is($match, $FALSE, "invalid passthrough sub-domain will not match TLD passthroughs");
cmp_deeply([], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("l.zamm.it");
is($match, $TRUE, "valid passthrough sub-domain will match passthroughs");
cmp_deeply(['tcp:80', 'tcp:443'], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("l.zamm.io");
is($match, $FALSE, "invalid passthrough sub-domain will not match passthroughs");
cmp_deeply([], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("ho.yes.hello");
is($match, $TRUE, "valid passthrough sub-domain that has a port will match passthroughs");
cmp_deeply(['udp:1234', 'tcp:1234'], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("ho.yes.io");
is($match, $FALSE, "invalid passthrough sub-domain that has a port will not match passthroughs");
cmp_deeply([], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("zamm.it");
is($match, $FALSE, "exact passthrough domain will not match wildcard passthroughs");
cmp_deeply([], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("yes.hello");
is($match, $FALSE, "exact passthrough domain that has a port will not match wildcard passthroughs");
cmp_deeply([], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("www.github.com");
is($match, $TRUE, "valid wildcard passthrough domain that multiple ports will match wildcard passthroughs");
cmp_deeply(['tcp:1234', 'tcp:80', 'tcp:443'], $ports, "ports for previous test are OK");

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

