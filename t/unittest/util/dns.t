#!/usr/bin/perl

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
use Test::More tests => 37;
#This test will running last
use Test::NoWarnings;
use Socket;

use pf::constants;
use_ok("pf::util::dns");

my ($match, $ports);

($match, $ports) = pf::util::dns::matches_passthrough(undef, 'passthroughs');
is($match, $FALSE, "undef domain will not match passthroughs");

eval {
    ($match, $ports) = pf::util::dns::matches_passthrough("zammitcorp.com", undef);
};
is($@, "Undefined passthrough zone provided\n", "undef zone will die with an error");

eval {
    ($match, $ports) = pf::util::dns::matches_passthrough("zammitcorp.com", "vidange");
};
is($@, "Invalid passthrough zone vidange\n", "undef zone will die with an error");

($match, $ports) = pf::util::dns::matches_passthrough("zammitcorp.com", 'passthroughs');
is($match, $TRUE, "valid passthrough domain will match passthroughs");
cmp_deeply(['tcp:80', 'tcp:443', 'tcp:22'], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("zammitcorp.io", 'passthroughs');
is($match, $FALSE, "invalid passthrough domain will not match passthroughs");
cmp_deeply([], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("dinde.ca", 'passthroughs');
is($match, $TRUE, "valid passthrough domain that has a port will match passthroughs");
cmp_deeply(['tcp:2828'], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("dinde.io", 'passthroughs');
is($match, $FALSE, "invalid passthrough domain that has a port will not match passthroughs");
cmp_deeply([], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("some.sub.domain.tld", 'passthroughs');
is($match, $TRUE, "valid passthrough sub-domain will match TLD passthroughs");
cmp_deeply(['tcp:80', 'tcp:443'], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("some.sub.domain.tld.com", 'passthroughs');
is($match, $FALSE, "invalid passthrough sub-domain will not match TLD passthroughs");
cmp_deeply([], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("l.zamm.it", 'passthroughs');
is($match, $TRUE, "valid passthrough sub-domain will match passthroughs");
cmp_deeply(['tcp:80', 'tcp:443'], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("l.zamm.io", 'passthroughs');
is($match, $FALSE, "invalid passthrough sub-domain will not match passthroughs");
cmp_deeply([], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("ho.yes.hello", 'passthroughs');
is($match, $TRUE, "valid passthrough sub-domain that has a port will match passthroughs");
cmp_deeply(['udp:1234', 'tcp:1234'], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("ho.yes.io", 'passthroughs');
is($match, $FALSE, "invalid passthrough sub-domain that has a port will not match passthroughs");
cmp_deeply([], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("zamm.it", 'passthroughs');
is($match, $FALSE, "exact passthrough domain will not match wildcard passthroughs");
cmp_deeply([], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("yes.hello", 'passthroughs');
is($match, $FALSE, "exact passthrough domain that has a port will not match wildcard passthroughs");
cmp_deeply([], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("www.github.com", 'passthroughs');
is($match, $TRUE, "valid wildcard passthrough domain that multiple ports will match wildcard passthroughs");
cmp_deeply(['tcp:1234', 'tcp:80', 'tcp:443'], $ports, "ports for previous test are OK");

# test isolation passthroughs

($match, $ports) = pf::util::dns::matches_passthrough("www.github.com", 'isolation_passthroughs');
is($match, $FALSE, "invalid passthrough shouldn't match");
cmp_deeply([], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("isolation.zammitcorp.com", 'isolation_passthroughs');
is($match, $TRUE, "normal isolation passthrough should match");
cmp_deeply(['tcp:80', 'tcp:443'], $ports, "ports for previous test are OK");

($match, $ports) = pf::util::dns::matches_passthrough("something.wild-isolation.zammitcorp.com", 'isolation_passthroughs');
is($match, $TRUE, "wildcard isolation passthrough should match");
cmp_deeply(['tcp:80', 'tcp:443'], $ports, "ports for previous test are OK");

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

