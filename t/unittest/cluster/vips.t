#!/usr/bin/perl

=head1 NAME

vips

=head1 DESCRIPTION

unit test for the cluster virtual IPs status of pf::cluster: the VRRP state
file written on each transition, and the aggregation of the status reported by
the members

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 17;

#This test will running last
use Test::NoWarnings;
use File::Temp qw(tempdir);
use JSON::MaybeXS;
use pf::cluster;

# keep the state files out of the real var/run
my $dir = tempdir(CLEANUP => 1);
{
    no warnings qw(redefine once);
    *pf::cluster::vip_state_file = sub { "$dir/keepalived-vip-$_[0].state" };
}

# state file round trip
{
    my $before = time;
    pf::cluster::record_vip_state('192.168.0.10', 'master');
    my $state = pf::cluster::read_vip_state('192.168.0.10');
    is($state->{state}, 'master', 'The recorded state is read back');
    ok($state->{since} >= $before && $state->{since} <= time, 'with the time of the transition');

    pf::cluster::record_vip_state('192.168.0.10', 'slave');
    is(pf::cluster::read_vip_state('192.168.0.10')->{state}, 'slave', 'A new transition replaces the state');

    is(pf::cluster::read_vip_state('192.168.0.11'), undef, 'No state for a virtual IP without a transition');

    pf::cluster::record_vip_state('../../etc/passwd', 'master');
    opendir(my $dh, $dir);
    is_deeply([ sort grep { !/^\./ } readdir($dh) ], ['keepalived-vip-192.168.0.10.state'], 'A virtual IP that is not an address is refused');
}

sub vip {
    my ($vip, $owner, %extra) = @_;
    return { vip => $vip, interface => 'eth0', management => \0, owner => ($owner ? \1 : \0), %extra };
}

sub by_vip {
    my ($items) = @_;
    return { map { (($_->{zone} // '') . "|" . $_->{vip}) => $_ } @$items };
}

# aggregation
{
    my $items = by_vip(pf::cluster::aggregate_vips_status([
        { host => 'pf1', zone => 'DC1', vips => [ vip('10.0.0.1', 1, state => 'master', since => 100), vip('10.0.1.1', 0) ] },
        { host => 'pf2', zone => 'DC1', vips => [ vip('10.0.0.1', 0, state => 'slave', since => 50), vip('10.0.1.1', 1, state => 'master', since => 200) ] },
        { host => 'pf3', zone => 'DC1', vips => [ vip('10.0.0.1', 0), vip('10.0.1.1', 1, state => 'master', since => 300) ] },
        { host => 'pf4', zone => 'DC2', vips => [ vip('10.1.0.1', 0) ] },
    ]));

    is_deeply($items->{'DC1|10.0.0.1'}{owners}, ['pf1'], 'The owner of a virtual IP');
    is($items->{'DC1|10.0.0.1'}{status}, 'ok', 'One owner is ok');
    is($items->{'DC1|10.0.0.1'}{since}, 100, 'Since is the time the owner became master');

    is_deeply($items->{'DC1|10.0.1.1'}{owners}, ['pf2', 'pf3'], 'Several owners');
    is($items->{'DC1|10.0.1.1'}{status}, 'split_brain', 'Several owners is a split brain');
    is($items->{'DC1|10.0.1.1'}{since}, 300, 'Since of a split brain is the latest master transition');

    is($items->{'DC2|10.1.0.1'}{status}, 'none', 'No owner');
}

# a member that couldn't be queried
{
    my $items = by_vip(pf::cluster::aggregate_vips_status([
        { host => 'pf1', zone => 'DC1', vips => [ vip('10.0.0.1', 0) ] },
        { host => 'pf2', zone => 'DC1', error => 'Unable to get the virtual IPs status' },
        { host => 'pf4', zone => 'DC2', vips => [ vip('10.1.0.1', 0) ] },
    ]));
    is($items->{'DC1|10.0.0.1'}{status}, 'unknown', 'No owner while a member of the zone could not be queried is unknown');
    is($items->{'DC2|10.1.0.1'}{status}, 'none', 'The members of another zone are not affected');
}

# booleans decoded from the JSON answer of a member
{
    my $vips = decode_json('[{"vip":"10.0.0.1","interface":"eth0","management":true,"owner":true,"state":"master","since":42},{"vip":"10.0.1.1","interface":"eth1","management":false,"owner":false}]');
    my $items = by_vip(pf::cluster::aggregate_vips_status([ { host => 'pf1', zone => 'DC1', vips => $vips } ]));
    is_deeply([ $items->{'DC1|10.0.0.1'}{status}, $items->{'DC1|10.0.1.1'}{status} ], [ 'ok', 'none' ], 'JSON booleans are understood');
}

is_deeply(pf::cluster::aggregate_vips_status([]), [], 'No member, no virtual IP');

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
