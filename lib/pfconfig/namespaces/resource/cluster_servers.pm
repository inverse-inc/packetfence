package pfconfig::namespaces::resource::cluster_servers;

=head1 NAME

pfconfig::namespaces::resource::fqdn

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::fqdn

=cut

use strict;
use warnings;

use pfconfig::namespaces::config::Cluster;

use base 'pfconfig::namespaces::resource';

sub init {
    my ($self, $cluster_name) = @_;

    $self->{cluster_name} = $cluster_name || "DEFAULT";
    $self->{cluster_resource} = pfconfig::namespaces::config::Cluster->new($self->{cache});
}

sub build {
    my ($self) = @_;
    my @cluster_ips;
    $self->{cluster_resource}->build();

    return $self->{cluster_resource}->{_servers}->{$self->{cluster_name}};
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

