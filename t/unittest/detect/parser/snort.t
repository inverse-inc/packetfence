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

my $alert = '07/28/2015-09:09:59.431113  [**] [1:2221002:1] SURICATA HTTP request field missing colon [**] [Classification: Generic Protocol Command Decode] [Priority: 3] {TCP} 10.220.10.186:44196 -> 199.167.22.51:8000';
 
my $parser = pf::factory::detect::parser->new('snort');
my $result = $parser->parse($alert);

is($result->{srcip}, "10.220.10.186");
is($result->{events}->{detect}, "2221002");
is($result->{events}->{suricata_event}, "SURICATA HTTP request field missing colon");

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
