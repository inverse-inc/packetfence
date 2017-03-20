package pf::multi_cluster;

use strict;
use warnings;

use Template;
use pf::ConfigStore::MultiCluster;
use pf::multi_cluster::region;
use pf::file_paths qw(
    $conf_dir
);
use File::Slurp qw(write_file);

sub rootRegions {
    my $regions = {};
    for my $root (@{rootRegionNames()}) {
        $regions->{$root} = pf::multi_cluster::region->new(name => $root);
    }
    return $regions;
}

sub rootRegionNames {
    my $cs = pf::ConfigStore::MultiCluster->new();
    my %allRegions;
    my %childRegions;
    for my $region (@{$cs->readAll("id")}) {
        $allRegions{$region->{id}} = 1;
        for my $childRegion (@{$region->{regions}}) {
            $allRegions{$childRegion} = 1;
            $childRegions{$childRegion} = 1;
        }
    }
    my @rootRegions = map { exists($childRegions{$_}) ? () : $_ } keys(%allRegions);
    return \@rootRegions;
}

sub generateAnsibleHosts {
    my ($dst) = @_;
    my $template = Template->new({ABSOLUTE => 1});
    my $output;
    $template->process($conf_dir."/ansible-hosts.tt", {regions => rootRegions()}, \$output) or die $template->error();
    write_file($dst, $output);
}

1;
