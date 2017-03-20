package pf::multi_cluster::server;

use Moose;
extends 'pf::multi_cluster::base';

use pf::log;
use pf::file_paths qw(
    $var_dir
);
use pf::util;

sub generateConfig {
    my ($self) = @_;
    for my $store (@{pf::cluster::stores_to_sync()}) {
        my $cs = $self->configStore($store);
        get_logger->info("Generating config of store $store for ".$self->path);

        my $dst_dir = $var_dir . "/conf/multi-cluster/" . $self->path; 
        my $dst_file = $dst_dir . "/" . $cs->cleanedFilePath($cs->configFile);

        pf_make_dir($dst_dir);
        touch_file($dst_file);
        pf_chown($dst_file);

        open(my $fh, ">" .$dst_file) or die "Can't open file: $!";
        $cs->cachedConfig->OutputConfigToFileHandle($fh, 0);
    }
}

1;
