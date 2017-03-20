package pf::multi_cluster::base;

use Moose;
use pf::cluster;
use pf::ConfigStore::MultiCluster;
use pf::log;

has 'name', is => 'rw';

has 'parent', is => 'rw';

sub ref {
    return ref($_[0]);
}

sub multiClusterConfigStore {
    return pf::ConfigStore::MultiCluster->new();
}

sub configStore {
    my ($self, $type) = @_;
    return $type->new(multiClusterHost => $self->path);
}

sub generateDeltas {
    my ($self) = @_;
    for my $store (@{pf::cluster::stores_to_sync()}) {
        get_logger->info("Commiting deltas of store $store for ".$self->path);
        my $cs = $self->configStore($store);
        $cs->commit;
    }
}

sub path {
    my ($self) = @_;
    return defined($self->parent) ? $self->parent . "/" . $self->name : $self->name;
}

sub generateConfig {
    # Implement me in childs
    die "generateConfig is unimplemented";
}

1;
