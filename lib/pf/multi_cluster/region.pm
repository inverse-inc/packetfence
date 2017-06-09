package pf::multi_cluster::region;

use Moose;
extends 'pf::multi_cluster::base';

use pf::log;
use pf::multi_cluster::cluster;
use pf::multi_cluster::standalone_server;

sub generateConfig {
    my ($self) = @_;

    my %childs = %{$self->childs};
    while(my ($child_id, $child) = each(%childs)) {
        $child->generateConfig();
    }
}

sub generateDeltas {
    my ($self) = @_;
    $self->SUPER::generateDeltas();

    my %childs = %{$self->childs};
    while(my ($child_id, $child) = each(%childs)) {
        get_logger->info("Commiting child delta of region ".$self->name.": $child_id");
        $child->generateDeltas();
    }
}

sub hasUnpushedChanges {
    my ($self) = @_;
    my %childs = %{$self->childs};
    for my $id (keys(%childs)) {
        get_logger->debug("Checking if child $id has unpushed changes");
        my $child = $childs{$id};
        return 1 if($child->hasUnpushedChanges());
    }
    return 0;
}

sub childs {
    my ($self) = @_;
    return { %{$self->regions}, %{$self->clusters}, %{$self->standalone_servers} };
}

sub childsByType {
    my ($self, $type) = @_;

    my $cs = $self->multiClusterConfigStore;
    my $config = $cs->read($self->name, "id");

    my %objects;

    my $section_name = $type . "s";

    for my $object (@{$config->{$section_name}}) {
        $objects{$object} = "pf::multi_cluster::$type"->new(name => $object, parent => $self->path);
    }

    return \%objects;
}

sub regions {
    my ($self) = @_;
    return $self->childsByType("region");
}

sub standalone_servers {
    my ($self) = @_;
    return $self->childsByType("standalone_server");
}

sub clusters {
    my ($self) = @_;
    return $self->childsByType("cluster");
}

1;
