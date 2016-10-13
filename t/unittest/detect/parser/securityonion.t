=head1 NAME

example pf test

=cut

=head1 DESCRIPTION

example pf test script

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

use Test::More tests => 5;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use_ok('pf::factory::detect::parser');

my $alert = 'Oct 28 13:37:42 poulichefencer sguil_alert: 13:37:42 pid(3403)  Alert Received: 0 2 misc-attack securityonion1-eth1 {2015-10-28 13:37:42} 3 88707 {ET TOR Known Tor Relay/Router (Not Exit) Node Traffic group 11} SRC.IP.AD.DR DST.IP.AD.DR 17 123 123 1 2522020 2376 7946 7946';

my $parser = pf::factory::detect::parser->new('security_onion');
my $result = $parser->parse($alert);

is($result->{date}, "2015-10-28 13:37:42");
is($result->{srcip}, "SRC.IP.AD.DR");
is($result->{dstip}, "DST.IP.AD.DR");
is($result->{events}->{detect}, "2522020");
is($result->{events}->{suricata_event}, "ET TOR Known Tor Relay/Router (Not Exit) Node Traffic group 11");

#This test will running last
use Test::NoWarnings;

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
