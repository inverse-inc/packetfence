package pf::multi_cluster;

use strict;
use warnings;

use Template;
use pf::log;
use pf::cluster;
use pf::ConfigStore::MultiCluster;
use pf::multi_cluster::region;
use pf::file_paths qw(
    $conf_dir
    $ansible_hosts_file
    $ansible_push_configuration_playbook_file
    $ansible_pull_configuration_playbook_file
    $ansible_restart_playbook_file
);
use File::Slurp qw(write_file);
use List::MoreUtils qw(uniq);

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

sub configFiles {
    my @files;
    for my $store (@{pf::cluster::stores_to_sync()}) {
        my $cs = $store->new;
        my $file = pf::file_paths::cleaned($cs->configFile);
        push @files, $file;
    }
    return [uniq(@files)];
}

sub generateAnsibleConfig {
    my $template = Template->new({ABSOLUTE => 1});

    my $dst = $ansible_hosts_file;
    my $output;
    $template->process($conf_dir."/ansible/hosts.tt", {regions => {rootRegion()->name => rootRegion()}}, \$output) or die $template->error();
    write_file($dst, $output);

    $dst = $ansible_push_configuration_playbook_file;
    $output = undef;
    $template->process($conf_dir."/ansible/packetfence-push-configuration.yml.tt", {configFiles => configFiles()}, \$output) or die $template->error();
    write_file($dst, $output);
    
    $dst = $ansible_pull_configuration_playbook_file;
    $output = undef;
    $template->process($conf_dir."/ansible/packetfence-pull-configuration.yml.tt", {configFiles => configFiles()}, \$output) or die $template->error();
    write_file($dst, $output);
    
    $dst = $ansible_restart_playbook_file;
    $output = undef;
    $template->process($conf_dir."/ansible/packetfence-restart.yml.tt", {}, \$output) or die $template->error();
    write_file($dst, $output);
}

sub findAnsiblePlaybook {
    my ($playbook) = @_;
    return unless(defined($playbook));
    $playbook = "/etc/ansible/packetfence-$playbook.yml";
    return (-f $playbook) ? $playbook : undef;
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
