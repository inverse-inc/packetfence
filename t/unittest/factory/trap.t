=head1 NAME

trap

=cut

=head1 DESCRIPTION

trap

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/lib /usr/local/pf/t);
    use PfFilePaths;
}

use Test::More tests => 3;                      # last test to print

use Test::NoWarnings;

use pf::factory::trap;

my $trapInfo = {
    'notificationtype' => 'TRAP',
    'receivedfrom'     => 'UDP: [192.168.0.2]:38033->[127.0.0.1]',
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
    ['.1.3.6.1.6.3.1.1.4.1.0', 'OID: .1.3.6.1.6.3.1.1.5.4', 6],
    ['.1.3.6.1.2.1.2.2.1.1.1', 'INTEGER: 1',                2]
];

my $trap = pf::factory::trap->instantiate($trapInfo,$oids);

ok( $trap , "pf::factory::trap->instantiate");

isa_ok( $trap , "pf::trap::up");

 
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


