package pf::multi_cluster;

use pf::ConfigStore::MultiCluster;
use pf::multi_cluster::region;

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

1;
