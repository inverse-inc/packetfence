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

use Test::More tests => 15;
#This test will running last
use Test::NoWarnings;
use Socket;

use pf::constants;
use_ok("pf::util::dns");

is(pf::util::dns::matches_passthrough(), $FALSE, "undef domain will not match passthroughs");

is(pf::util::dns::matches_passthrough("zammitcorp.com"), $TRUE, "valid passthrough domain will match passthroughs");

is(pf::util::dns::matches_passthrough("zammitcorp.io"), $FALSE, "invalid passthrough domain will not match passthroughs");

is(pf::util::dns::matches_passthrough("dinde.ca"), $TRUE, "valid passthrough domain that has a port will match passthroughs");

is(pf::util::dns::matches_passthrough("dinde.io"), $FALSE, "invalid passthrough domain that has a port will not match passthroughs");

is(pf::util::dns::matches_passthrough("some.sub.domain.tld"), $TRUE, "valid passthrough sub-domain will match TLD passthroughs");

is(pf::util::dns::matches_passthrough("some.sub.domain.tld.com"), $FALSE, "invalid passthrough sub-domain will not match TLD passthroughs");

is(pf::util::dns::matches_passthrough("l.zamm.it"), $TRUE, "valid passthrough sub-domain will match passthroughs");

is(pf::util::dns::matches_passthrough("l.zamm.io"), $FALSE, "invalid passthrough sub-domain will not match passthroughs");

is(pf::util::dns::matches_passthrough("ho.yes.hello"), $TRUE, "valid passthrough sub-domain that has a port will match passthroughs");

is(pf::util::dns::matches_passthrough("ho.yes.io"), $FALSE, "invalid passthrough sub-domain that has a port will not match passthroughs");

is(pf::util::dns::matches_passthrough("zamm.it"), $TRUE, "valid passthrough domain will match wildcard passthroughs");

is(pf::util::dns::matches_passthrough("yes.hello"), $TRUE, "valid passthrough domain that has a port will match wildcard passthroughs");

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

