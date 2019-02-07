package pfconfig::namespaces::config::Cluster;

=head1 NAME

pfconfig::namespaces::config::Cluster

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Cluster

This module creates the configuration hash associated to cluster.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::util;
use pf::file_paths qw($cluster_config_file);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self, $cluster_name) = @_;
    $self->{cluster_name} = $cluster_name || "DEFAULT";
    $self->{file} = $cluster_config_file;
    $self->{child_resources} = ['config::Pf', 'config::Network', 'resource::cluster_servers', 'resource::cluster_hosts', 'resource::network_config', 'resource::clusters_hostname_map'];

    $self->{hostname_map} = {};
}

sub build_child {
    my ($self) = @_;

    my %cfg = %{$self->{cfg}};
    $self->cleanup_whitespaces(\%cfg);

    if($cfg{general} && isenabled($cfg{general}{multi_zone})) {
        $self->{multi_zone_enabled} = 1;
        $self->{cluster_enabled} = 1;
        return $self->build_multi_zone(\%cfg);
    }
    else {
        $self->{multi_zone_enabled} = 0;
        $self->{cluster_enabled} = $cfg{CLUSTER}{management_ip} ? 1 : 0;
        return $self->build_single_cluster("DEFAULT", $self->{ordered_sections}, \%cfg);
    }
}

=head2 build_multi_zone

Build the cluster configuration when cluster.conf is used in multi zone mode

=cut

sub build_multi_zone {
    my ($self, $cfg) = @_;

    my %tmp_cfg;

    # Ensure the default cluster has at least an empty hashref
    $tmp_cfg{DEFAULT} = {};

    my @clusters;
    foreach my $section (@{$self->{ordered_sections}}){
        # we don't want double groups
        if ($section =~ m/^([a-zA-Z0-9]+)\s[a-zA-Z0-9]+$/i) {
            push @clusters, $1;
        }
    }

    foreach my $cluster (@clusters) {
        map { 
            $_ =~ s/^$cluster //g;
            $tmp_cfg{$cluster}{$_} = $cfg->{"$cluster $_"};
        } $self->GroupMembers($cluster);
        my $ordered_sections = [ map{ 
            $_ =~ s/^$cluster //g ? $_ : ();
        } @{$self->{ordered_sections}}];
        $tmp_cfg{$cluster} = $self->build_single_cluster($cluster, $ordered_sections, $tmp_cfg{$cluster});
    }

    return $tmp_cfg{$self->{cluster_name}};
}

=head2 build_single_cluster

Build cluster configuration when cluster.conf isn't in multi zone mode

=cut

sub build_single_cluster {
    my ($self, $cluster_name, $ordered_sections, $cfg) = @_;

    my @servers;
    my %tmp_cfg;

    foreach my $section (@$ordered_sections){
        # we don't want groups
        next if ($section =~ m/\s/i);

        my $server = $cfg->{$section};

        foreach my $group (keys(%$cfg)){
            # we want only groups of that section
            next if($group !~ /^$section\s/);
            $group =~ s/^$section //g;
            $server->{$group} = $cfg->{"$section $group"};
        }

        $tmp_cfg{$section} = $server;

        $server->{host} = $section;
        # we add it to the servers list if it's not the shared CLUSTER config
        if ($section eq "CLUSTER") {
            $self->{_CLUSTER}->{$cluster_name} = $server;
        }
        else {
            push @servers, $server;
        }

        # Add it to the map for getting the cluster name of a server
        die "The same hostname ($section) is declared in two different clusters (".$self->{hostname_map}->{$section}." and $cluster_name). This is currently unsupported\n" 
            if($section ne "CLUSTER" && defined($self->{hostname_map}->{$section}) && $self->{hostname_map}->{$section} ne $cluster_name);

        $self->{hostname_map}->{$section} = $cluster_name;
    }

    $self->{_servers}->{$cluster_name} = \@servers;

    return \%tmp_cfg;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

