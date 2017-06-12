package pf::multi_cluster::cluster;

use Moose;
extends 'pf::multi_cluster::server';

use pf::multi_cluster::cluster_server;
use pf::ConfigStore::Cluster;
use pf::cluster;

sub clusterConf {
    my ($self) = @_;
    return pf::ConfigStore::Cluster->new(multiClusterHost => $self->path);
}

sub generateConfig {
    my ($self) = @_;
    $self->SUPER::generateConfig();

    my %childs = %{$self->childs};
    while(my ($child_id, $child) = each(%childs)) {
        $child->generateConfig();
    }
}

sub childs {
    my ($self) = @_;
    my @ids = map { ($_ =~ m/\s/i || $_ eq $CLUSTER) ? () : $_ } @{$self->clusterConf->readAllIds()};
    return { map { $_ => pf::multi_cluster::cluster_server->new(name => $_, parent => $self) } @ids };
}

1;
