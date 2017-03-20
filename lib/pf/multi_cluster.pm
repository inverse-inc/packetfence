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

sub rootRegion {
    return pf::multi_cluster::region->new(name => "ROOT");
}

sub findObject {
    my ($group, $id) = @_;
    if($group->can('childs')) {
        if(exists $group->childs->{$id}) {
            return $group->childs->{$id};
        }
        else {
            my %childs = %{$group->childs};
            while(my ($child_id, $child) = each(%childs)) {
                my $object = findObject($child, $id);
                if(defined($object)) {
                    return $object;
                }
            }
            # Return undef if nothing was found above as it should have already returned
            return undef;
        }
    }
    else {
        return undef;
    }
}

sub generateAnsibleHosts {
    my ($dst) = @_;
    my $template = Template->new({ABSOLUTE => 1});
    my $output;
    $template->process($conf_dir."/ansible-hosts.tt", {regions => [rootRegion()]}, \$output) or die $template->error();
    write_file($dst, $output);
}

sub generateConfig {
    my $region = defined($_[0]) ? $_[0] : rootRegion();
    $region->generateConfig();
}

sub generateDeltas {
    my $region = defined($_[0]) ? $_[0] : rootRegion();
    $region->generateDeltas();
}

1;
