package pf::services::manager::radsniff;

=head1 NAME

pf::services::manager::radsniff management module.

=cut

=head1 DESCRIPTION

pf::services::manager::radsniff

=cut

use strict;
use warnings;
use pf::file_paths qw($install_dir);
use pf::util;
use pf::config qw($management_network);
use Moo;
use pf::cluster;
use pf::config qw(@radius_ints);
use List::MoreUtils qw(uniq);

extends 'pf::services::manager';

has '+name' => ( default => sub {'radsniff'} );
has '+optional' => ( default => sub {1} );

=head2 make_filter

Generate the filter based on the radius interfaces.

=cut

sub make_filter {
    my  @ints = uniq(@radius_ints);
    my $filter = '( ( ';
    my @array;
    foreach my $int (@ints) {
        my $interface = $int->{Tint};
        my $members_ips = pf::cluster::members_ips($interface);
        push(@array, $members_ips->{$host_id});
    }
    $filter .= join(" or ",  map { "host $_"} @array);
    $filter .= ') and ( ';
    $filter .= ' udp port 1812 or 1813) ) ';
    return $filter;
}

sub _cmdLine {
    my $self = shift;
    if ($cluster_enabled) {
        my $cluster_management_ip = pf::cluster::management_cluster_ip();
        my $management_ip         = pf::cluster::current_server()->{management_ip};
        my $filter = make_filter();
        my $ints = join(' ', map { "-i $_->{Tint}"} @radius_ints);
        $self->executable . " -d $install_dir/raddb/ -D $install_dir/raddb/ -q -W10 -O $install_dir/var/run/collectd-unixsock -f '$filter' $ints -i lo";
    }
    else {
        $self->executable . " -d $install_dir/raddb/ -D $install_dir/raddb/ -q -W10 -O $install_dir/var/run/collectd-unixsock -i $management_network->{Tint}";
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
