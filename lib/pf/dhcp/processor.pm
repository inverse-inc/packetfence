package pf::dhcp::processor;

=head1 NAME

pf::dhcp::processor

=cut

=head1 DESCRIPTION

Base class for processing DHCP packets

=cut

use strict;
use warnings;

# External libs
use Readonly;

# Internal libs
use pf::access_filter::dhcp;
use pf::client;
use pf::log;
use pf::node;

use Moose;


has 'apiClient'    => (is => 'ro', default => sub { pf::client::getClient });
has 'filterEngine' => (is => 'rw', default => sub { pf::access_filter::dhcp->new });


Readonly::Hash my %FINGERBANK_ATTRIBUTES_MAP => (
    client_mac              => 'mac',
    client_ip               => 'ip',
    client_hostname         => 'computername',
    ipv4_requested_options  => 'dhcp_fingerprint',
    ipv4_vendor             => 'dhcp_vendor',
    ipv6_requested_options  => 'dhcp6_fingerprint',
    ipv6_vendor             => 'dhcp_vendor',
    ipv6_enterprise_number  => 'dhcp6_enterprise',
);


sub processFingerbank {
    my ( $self, $attributes ) = @_;
    my $logger = pf::log::get_logger();

    my $fingerbank_args = {};
    foreach my $key ( keys %{$attributes} ) {
        if ( exists $FINGERBANK_ATTRIBUTES_MAP{$key} ) {
            if ( ref($attributes->{$key}) eq 'ARRAY' ) {
                $fingerbank_args->{$FINGERBANK_ATTRIBUTES_MAP{$key}} = join ',', @{$attributes->{$key}};
            }
            else {
                $fingerbank_args->{$FINGERBANK_ATTRIBUTES_MAP{$key}} = $attributes->{$key};
            }
        }
    }

    my $dhcp_filter_rule = $self->filterEngine->filter('Fingerbank', $fingerbank_args);

    unless ( $dhcp_filter_rule ) {
        $self->apiClient->notify('fingerbank_process', $fingerbank_args);
        pf::node::node_modify($fingerbank_args->{'mac'}, %{$fingerbank_args});
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

__PACKAGE__->meta->make_immutable;

1;
