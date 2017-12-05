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

my $alert = 'Nov 13 11:38:09 172.20.120.70 Nexpose: 10.0.0.20 VULNERABILITY: OpenSSL SSL/TLS MITM vulnerability (CVE-2014-0224) (http-openssl-cve-2014-0224)';
 
my $parser = pf::factory::detect::parser->new('nexpose');
my $result = $parser->parse($alert);

is($result->{dstip}, "10.0.0.20");
is($result->{srcip}, "172.20.120.70");
is($result->{events}->{nexpose_event}, "OpenSSL SSL/TLS MITM vulnerability (CVE-2014-0224) (http-openssl-cve-2014-0224)");

# non-matching alert coming from nexpose
$alert = "Dec 4 11:34:27 172.20.120.70 Nexpose: SCAN STARTED: Zammit-Site";
$result = $parser->parse($alert);

is($result, undef);

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
