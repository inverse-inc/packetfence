package pf::multi_cluster::cluster_server;

use Moose;
extends 'pf::multi_cluster::server';

sub configStore {
    my $self = shift;
    return $self->parent->configStore(@_);
}

1;

