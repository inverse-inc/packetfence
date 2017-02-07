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

has '+launcher' => (
    default => sub {
        if($cluster_enabled){
          my $cluster_management_ip = pf::cluster::management_cluster_ip();
          my $management_ip = pf::cluster::current_server()->{management_ip};
          my $filter = make_filter();
          my $ints = join(' ', map { "-i $_->{Tint}"} @radius_ints);
          "sudo %1\$s -d $install_dir/raddb/ -D $install_dir/raddb/ -q -P $install_dir/var/run/radsniff.pid -W10 -O $install_dir/var/run/collectd-unixsock -f '$filter' $ints -i lo";
        }
        else {
          "sudo %1\$s -d $install_dir/raddb/ -D $install_dir/raddb/ -q -P $install_dir/var/run/radsniff.pid -W10 -O $install_dir/var/run/collectd-unixsock -i $management_network->{Tint}";
        }
    }
);

has startDependsOnServices => ( is => 'ro', default => sub { [qw(collectd)] } );

=head2 make_filter

Generate the filter based on the radius interfaces.

=cut

sub make_filter {
    my  @ints = uniq(@radius_ints);
    my $filter = '( ( ';
    my @array;
    foreach my $int (@ints) {
        my $interface = $int->{Tint};
        push(@array, pf::cluster::cluster_ip($interface));
    }
    $filter .= join(" or ",  map { "host $_"} @array);
    $filter .= ') and ( ';
    $filter .= ' udp port 1812 or 1813) ) ';
    return $filter;
}

1;
