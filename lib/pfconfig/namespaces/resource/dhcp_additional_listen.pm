package pfconfig::namespaces::resource::dhcp_additional_listen;

=head1 NAME

pfconfig::namespaces::resource::dhcp_additional_listen

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::dhcp_additional_listen

=cut

use strict;
use warnings;
use pf::util;

use base 'pfconfig::namespaces::resource';
use pfconfig::namespaces::config::Network;

sub init {
    my ($self, $host_id) = @_;
    $host_id //= "";

    $self->{cluster_name} = ($host_id ? $self->{cache}->get_cache("resource::clusters_hostname_map")->{$host_id} : undef) // "DEFAULT";

    $self->{networks} = $self->{cache}->get_cache("config::Network($host_id)");
    $self->{cluster_resource} = pfconfig::namespaces::config::Cluster->new($self->{cache}, $self->{cluster_name});

}

sub build {
    my ($self) = @_;

    $self->{cluster_resource}->build();

    my @additional_dhcp;

    foreach my $network ( keys %{$self->{networks}} ) {
        if ( defined($self->{networks}{$network}{dev}) && $self->{networks}{$network}{dev} ne "") {
            push @additional_dhcp ,  map { $_ } split(',',$self->{networks}{$network}{dev});
        }
    }
    return \@additional_dhcp;
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

