#!/usr/bin/perl

=head1 NAME

checkup_multi_zone_interfaces

=head1 DESCRIPTION

unit test for pf::pfcmd::checkup::multi_zone_interface_problems: the interfaces
of pf.conf ignored on servers of a multi-zone cluster

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 5;
use Test::NoWarnings;
use pf::pfcmd::checkup;

sub server { my ($host, @ints) = @_; return { host => $host, map { ("interface $_" => {}) } @ints } }
sub problems { return [ pf::pfcmd::checkup::multi_zone_interface_problems(@_) ] }

my @ints = ({ name => 'ens18' }, { name => 'ens19' });
# the lab: DC1 has ens18 and ens19, DC2 only ens18
my @dc1 = (server('CLUSTER', 'ens18', 'ens19'), server('pf1', 'ens18', 'ens19'), server('pf2', 'ens18', 'ens19'));
my @dc2 = (server('CLUSTER', 'ens18'), server('pf4', 'ens18'));
my %zones = (DC1 => \@dc1, DC2 => \@dc2);

is_deeply(problems(\@ints, \@dc1, \%zones), [], 'zone with all its interfaces: no problem');
is_deeply(problems(\@ints, \@dc2, \%zones), [], 'zone without an interface at all: no problem');

my @dc1_missing = (server('CLUSTER', 'ens18', 'ens19'), server('pf1', 'ens18', 'ens19'), server('pf2', 'ens18'));
is_deeply(
    problems(\@ints, \@dc1_missing, { DC1 => \@dc1_missing, DC2 => \@dc2 }),
    [ 'Interface ens19 is defined for other servers of this zone but not for pf2 in cluster.conf: it is ignored on pf2' ],
    'server of the zone without an interface the other servers have'
);

is_deeply(
    problems([ @ints, { name => 'ens20' } ], \@dc1, \%zones),
    [ 'Interface ens20 of pf.conf is defined for no server in cluster.conf: it is ignored on every server' ],
    'interface of pf.conf defined for no server'
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

