=head1 NAME

suricata_md5_smtp

=cut

=head1 DESCRIPTION

suricata smtp extraction

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

my $alert = 'Jul  7 15:49:43 Thierry-SecurityOnion suricata_files: { "timestamp": "07\/07\/2016-15:49:42.981092", "ipver": 4, "srcip": "172.20.20.211", "dstip": "10.0.0.6", "protocol": 6, "sp": 54591, "dp": 25, "message-id": "<20160707154942.GA2239@Thierry-SecurityOnion>", "sender": "tlaurion <tlaurion@Thierry-SecurityOnion>", "filename": "3july2.exe", "magic": "PE32 executable (GUI) Intel 80386, for MS Windows", "state": "CLOSED", "md5": "0806b949be8f93127a9fbf909221a121", "stored": false, "size": 1145856 }';
my $parser = pf::factory::detect::parser->new('suricata_md5');
my $result = $parser->_parse($alert);

ok(defined($result->{sender}), "checking that smtp method is recognised so we know who is the possible infected endpoint.");
is($result->{srcip}, "172.20.20.211", "checking source IP is properly parsed.");
is($result->{md5}, "0806b949be8f93127a9fbf909221a121", "checking that md5 is properly parsed.");


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
