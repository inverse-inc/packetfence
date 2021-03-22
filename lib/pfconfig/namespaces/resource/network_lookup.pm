package pfconfig::namespaces::resource::network_lookup;

=head1 NAME

pfconfig::namespaces::resource::network_lookup -

=head1 DESCRIPTION

pfconfig::namespaces::resource::network_lookup

=cut

use strict;
use warnings;
use base 'pfconfig::namespaces::resource';
use pfconfig::namespaces::config::Network;
use NetAddr::IP;
use pf::constants qw($DEFAULT_TENANT_ID);

sub init {
    my ($self, $host_id) = @_;
    $host_id //= '';
    $self->{networks} = $self->{cache}->get_cache("config::Network($host_id)");
}

sub build {
    my ($self) = @_;
    my @networkTenantLookup;
    while (my ($id, $data) = each %{$self->{networks}}) {
        push @networkTenantLookup, [ NetAddr::IP->new($data->{network}, $data->{netmask}) ,$data];
    }

    @networkTenantLookup = sort { $b->[0]->masklen <=> $a->[0]->masklen } @networkTenantLookup;
    return \@networkTenantLookup;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
