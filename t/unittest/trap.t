=head1 NAME

trap

=cut

=head1 DESCRIPTION

trap

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);

use Test::More tests => 4;                      # last test to print

use Test::NoWarnings;

use_ok("pf::trap");

my $trapInfo = {
    'notificationtype' => 'TRAP',
    'receivedfrom'     => 'UDP: [127.0.0.1]:38033->[127.0.0.1]',
    'version'          => 1,
    'errorstatus'      => 0,
    'messageid'        => 0,
    'community'        => 'public',
    'transactionid'    => 2,
    'errorindex'       => 0,
    'requestid'        => 763830387
};

my $oids = [
    ['.1.3.6.1.2.1.1.3.0',     'Timeticks: (0) 0:00:00.00', 67],
    ['.1.3.6.1.6.3.1.1.4.1.0', 'OID: .1.3.6.1.6.3.1.1.5.3', 6],
    ['.1.3.6.1.2.1.2.2.1.1.1', 'INTEGER: 1',                2]
];

my $trap = new_ok("pf::trap" => [{trapInfo => $trapInfo,oids => $oids}]);


ok($trap->ifIndex == 1,"Trap ifIndex equals 1");


 
=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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


