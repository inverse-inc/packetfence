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
use pf::file_paths;

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = "/usr/local/pf/conf/cluster.conf";
    $self->{child_resources} = ['config::Pf', 'resource::cluster_servers', 'resource::cluster_hosts'];
}

sub build_child {
    my ($self) = @_;

    my %cfg = %{$self->{cfg}};
    $self->cleanup_whitespaces(\%cfg);
    my @servers;
    my %tmp_cfg;

    foreach my $section (@{$self->{ordered_sections}}){
        # we don't want groups
        next if ($section =~ m/\s/i);

        my $server = $cfg{$section};
        
        foreach my $group ($self->GroupMembers($section)){
            $group =~ s/^$section //g;
            $server->{$group} = $cfg{"$section $group"};
        }
  
        $tmp_cfg{$section} = $server;

        $server->{host} = $section;
        # we add it to the servers list if it's not the shared CLUSTER config
        push @servers, $server unless $section eq "CLUSTER";
    }

    $self->{_servers} = \@servers;

    return \%tmp_cfg;

}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

