package pfconfig::namespaces::interfaces::inline_nets;

=head1 NAME

pfconfig::namespaces::interfaces::inline_nets

=cut

=head1 DESCRIPTION

pfconfig::namespaces::interfaces::inline_nets

=cut

use strict;
use warnings;
use pfconfig::namespaces::config::Network;

use base 'pfconfig::namespaces::interfaces';

sub init {
    my ($self, $host_id) = @_;
    $host_id //= "";
    $self->{network_config} = $self->{cache}->get_cache("config::Network($host_id)");
}

sub build {
    my ($self)         = @_;
    my %ConfigNetworks = %{ $self->{network_config} };
    my @inline_nets    = ();
    foreach my $network ( keys %ConfigNetworks ) {
        my $type = $ConfigNetworks{$network}{type};
        if ( pfconfig::namespaces::config::Network::is_network_type_inline($type) ) {
            my $inline_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
            push @inline_nets, $inline_obj;
        }
    }
    return \@inline_nets;
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

