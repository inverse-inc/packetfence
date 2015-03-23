package pf::cluster;

use strict;
use warnings;

use pf::log;
use Sys::Hostname;
use pfconfig::cached_hash;
use pfconfig::cached_array;
use pfconfig::cached_scalar;
use List::MoreUtils qw(first_index);
use Net::Interface;
use NetAddr::IP;
use Socket;

use Exporter;
our ( @ISA, @EXPORT );
@ISA = qw(Exporter);
@EXPORT = qw(%ConfigCluster @cluster_servers @cluster_hosts $cluster_enabled $host_id $CLUSTER);

our ($cluster_enabled, %ConfigCluster, @cluster_servers, @cluster_hosts);
tie %ConfigCluster, 'pfconfig::cached_hash', 'config::Cluster';
tie @cluster_servers, 'pfconfig::cached_array', 'resource::cluster_servers';
tie @cluster_hosts, 'pfconfig::cached_array', 'resource::cluster_hosts';
tie $cluster_enabled, 'pfconfig::cached_scalar', 'resource::cluster_enabled';

our $CLUSTER = "CLUSTER";

our $host_id = hostname();

# we comment so we're not dependent to pfconfig during the use
#if($cluster_enabled && !exists($ConfigCluster{$host_id})){
#    my $logger = get_logger;
#    $logger->error("This machine ($host_id) is cluster enabled but doesn't have a cluster configuration. This will certainly cause problems. Please check your cluster.conf or disable clustering on this server.");
#}

sub is_management {
    my $cluster_ip = management_cluster_ip();
    my @all_ifs = Net::Interface->interfaces();
    foreach my $inf (@all_ifs) {
        my @masks = $inf->netmask(AF_INET());
        my @addresses = $inf->address(AF_INET());
        for my $i (0 .. $#masks) {
            if (inet_ntoa($addresses[$i]) eq $cluster_ip) {
                return 1;
            }
        }
    }
    return 0;

}

sub cluster_ip {
    my ($interface) = @_;
    return $ConfigCluster{$CLUSTER}->{"interface $interface"}->{ip};
}

sub management_cluster_ip {
    return $ConfigCluster{$CLUSTER}->{management_ip};
}

sub cluster_index {
    my $cluster_index = first_index { $_ eq $host_id } @cluster_hosts;
    return $cluster_index;
}

sub is_dhcpd_primary {
    if(scalar(@cluster_servers) > 1){
        # the non-management node is the primary
        return cluster_index() == 1 ? 1 : 0;
    }
    else {
        # the server is alone so it's the primary
        return 1;
    }
}

sub should_offer_dhcp {
    cluster_index() <= 1 ? 1 : 0;
}

sub dhcpd_peer {
    my ($interface) = @_;
    
    unless(defined($cluster_servers[1])){
        return undef;
    }

    if(cluster_index() == 0){
        return $cluster_servers[1]{"interface $interface"}->{ip};
    }
    else {
        return $cluster_servers[0]{"interface $interface"}->{ip};
    }
}

sub mysql_servers {
    if(scalar(@cluster_servers) >= 1){
        # we make the prefered management node the last prefered for MySQL
        my @servers = @cluster_servers;
        my $management = shift @servers;
        push @servers, $management;
        return @servers;
    }
    else{
        return @cluster_servers;
    }
}

sub members_ips {
    my ($interface) = @_;
    my $logger = get_logger;
    unless(exists($ConfigCluster{$host_id}->{"interface $interface"}->{ip})){
        $logger->error("requesting member ips for an undefined interface...");
        return undef;
    }
    my %data = map { $_->{host} => $_->{"interface $interface"}->{ip} } @cluster_servers;
    return \%data;
}

1;
