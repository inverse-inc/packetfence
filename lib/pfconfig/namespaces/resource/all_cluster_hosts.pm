package pfconfig::namespaces::resource::all_cluster_hosts;

=head1 NAME
pfconfig::namespaces::resource::all_cluster_hosts
=cut

=head1 DESCRIPTION
pfconfig::namespaces::resource::all_cluster_hosts
=cut

use strict;
use warnings;

use base 'pfconfig::namespaces::resource';
use pfconfig::namespaces::config::Cluster;

=head2 init

Initialize the namespace

=cut

sub init {
    my ($self, $cluster_name) = @_;

    $self->{cluster_name} = $cluster_name || "DEFAULT";
    $self->{cluster_resource} = pfconfig::namespaces::config::Cluster->new($self->{cache});
}

=head2 build

Build the list of all servers in the cluster (including the ones across multiple L3 zones)

=cut

sub build {
    my ($self) = @_;
    my @cluster_ips;
    $self->{cluster_resource}->build();

    my @servers;
    for my $cluster_name (keys(%{$self->{cluster_resource}->{_servers}})) {
        push @servers, @{$self->{cluster_resource}->{_servers}->{$cluster_name}};
    }

    @servers = map{$_->{host}} @servers;

    return \@servers;
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

