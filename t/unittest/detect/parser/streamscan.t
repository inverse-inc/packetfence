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

my $alert = 'Apr 24 16:50:41 ubuntu CDS[13423]: type=alert threat="ET TROJAN Likely Zbot Generic Post to gate.php no accept headers" direction=outgoing sourceip=192.168.254.194 sourceport=53252 destip=5.175.143.42 destport=80 app=HTTP timestamp=2017-04-24_16-50-41.832096 sid=2022985';
 
my $parser = pf::factory::detect::parser->new('streamscan');
my $result = $parser->parse($alert);

is($result->{srcip}, "192.168.254.194");
is($result->{events}->{detect}, "2022985");
is($result->{events}->{suricata_event}, "ET TROJAN Likely Zbot Generic Post to gate.php no accept headers");

#This test will running last
use Test::NoWarnings;

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
