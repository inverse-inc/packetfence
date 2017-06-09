package pf::multi_cluster::base;

use Moose;
use pf::file_paths qw(
    $multi_cluster_conf_dir
);
use pf::cluster;
use pf::ConfigStore::MultiCluster;
use pf::log;
use File::Find;

has 'name', is => 'rw';

has 'parent', is => 'rw';

sub ref {
    return ref($_[0]);
}

sub multiClusterConfigStore {
    return pf::ConfigStore::MultiCluster->new();
}

sub hasUnpushedChanges {
    my ($self) = @_;

    # TODO, change to a variable
    my $deployed_dir = "/usr/local/pf/var/deployed/".$self->path;

    unless(-d $deployed_dir) {
        get_logger->warn("$deployed_dir doesn't exist, considering all local changes as unpushed.");
        return 1;
    }

    my $pushed_timestamp = (stat($deployed_dir))[9];

    my $path = $multi_cluster_conf_dir . "/" . $self->path;
    opendir(DIR, $path) or die $!;

    while(my $file = readdir(DIR)) {
        # Skipping hidden files, and '.' + '..'
        next if($file =~ /^\./);
        # Skipping directories, only looking at files
        next if(-d "$path/$file");

        if ((stat("$path/$file"))[9] > $pushed_timestamp) {
            get_logger->info($file . " is newer than the last deployed version");
            return 1;
        }
    }

    return 0;
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
