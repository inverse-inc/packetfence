=head1 NAME

Securityonion.t

=cut

=head1 DESCRIPTION

SecurityOnion unit test: validate that the security_onion parser returns good values that we here test against.

=cut

use strict;
use warnings;
use lib '/usr/local/pf/lib';

use Test::More tests => 7;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use_ok('pf::factory::detect::parser');

my $alert = 'Oct  7 14:23:40 idsman01 securityonion_ids: 14:23:40 pid(24921)  Alert Received: 0 1 policy-violation idshalls01-eth0-7 {2016-10-07 14:23:39} 21 173773 {ET P2P Vuze BT UDP Connection} 10.6.198.173 24.122.228.33 17 10600 65344 1 2010140 6 92 92';

my $parser = pf::factory::detect::parser->new('security_onion');
my $result = $parser->parse($alert);

is($result->{date}, "2016-10-07 14:23:39");
is($result->{srcip}, "10.6.198.173");
is($result->{dstip}, "24.122.228.33");
is($result->{events}->{detect}, "2010140");
is($result->{events}->{suricata_event}, "ET P2P Vuze BT UDP Connection");

#This test will running last
use Test::NoWarnings;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
