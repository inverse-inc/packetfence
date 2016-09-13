=head1 NAME

Test for Infoblox syslog DHCP parser

=cut

use strict;
use warnings;
use lib '/usr/local/pf/lib';

use Test::More tests => 8;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use_ok('pf::factory::detect::parser');

my $infos = {
    "Sep  1 03:27:04 172.22.0.3 dhcpd[20512]: DHCPACK to 172.19.16.171 (00:11:22:33:44:55) via eth1" => {
        type => "DHCPACK",
        ip => "172.19.16.171",
        mac => "00:11:22:33:44:55",
    },
    "Sep  1 03:27:05 172.26.0.139 dhcpd[14557]: DHCPACK on 10.16.86.122 to 00:11:22:33:44:55 (blabla-computer) via eth2 relay eth2 lease-duration 86400 (RENEW) uid 00:11:22:33:44:55" => {
        type => "DHCPACK",
        ip => "10.16.86.122",
        mac => "00:11:22:33:44:55",
    },
    "Sep  1 03:27:22 172.22.0.3 dhcpd[20512]: balancing pool 21960d0 172.31.3.0/24  total 17  free 0  backup 1  lts 1  max-own (+/-)0" => {},
};
 
my $parser = pf::factory::detect::parser->new('infoblox_dhcp');
while(my ($line, $expected) = each(%$infos)) {
    my $result = $parser->_parse($line);
    foreach my $key (keys(%$result)) {
        is($result->{$key}, $expected->{$key});
    }
}
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
