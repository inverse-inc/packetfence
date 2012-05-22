package configurator::Model::Config;

=head1 NAME

configurator::Model::Config - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

use Config::IniFiles;
use IO::Interface::Simple;
use Moose;
use namespace::autoclean;

use pf::config;

extends 'Catalyst::Model';

=head1 METHODS

=over

=item _calculateNetworkAddress

Calculate the network address for the provided ipaddress/network combination

=cut
sub _calculateNetworkAddress {
    my ( $self, $ipaddress, $netmask ) = @_;

    my @ipaddress   = split(/\./,$ipaddress);
    my @netmask     = split(/\./,$netmask);
    $ipaddress      = unpack( "N", pack( "C4", @ipaddress ) );
    $netmask        = unpack( "N", pack( "C4", @netmask ) );

    my $networkaddress  = ( $ipaddress & $netmask );
    my @networkaddress  = unpack( "C4", pack( "N", $networkaddress ) );
    $networkaddress     = join( ".", @networkaddress );

    return $networkaddress;
}

=item _getInterfaceType

Private method to be used when reading the pf.conf/pf.conf.default files

Used to return the correct interface type by matching networks.conf and pf.conf configurations

=cut
sub _getInterfaceType {
    my ( $self, $interface ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $type;

    # Since only networks.conf contain the type of the interface, we need to make the match
    # with the IP of the interface and the declaration using the same network address as the ip address
    # TODO: Get rid of this when we'll get rid of the networks.conf file
    my $interface_obj   = IO::Interface::Simple->new($interface);
    my $ipaddress       = $interface_obj->address;
    my $netmask         = $interface_obj->netmask;
    my $networkaddress  = $self->_calculateNetworkAddress($ipaddress, $netmask);

    my %networks_cfg = $self->_readNetworksConf();
    $type = $networks_cfg{$networkaddress}{'type'};

    if ( $type =~ /vlan-/ ) {
        $type = substr $type, 5;
    }

    return $type;
}

=item _readNetworksConf

TODO: Get rid of this when we'll get rid of the networks.conf file

Used to read the networks.conf configuration file

=cut
sub _readNetworksConf {
    my ( $self ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my %networks_conf;

    tie (%networks_conf, 'Config::IniFiles', (-file => "$install_dir/conf/networks.conf"));

    if ( !%networks_conf ) {
        $logger->warn("Unable to read conf/networks.conf file");
        return;
    }

    return %networks_conf;
}

=back

=head1 AUTHORS

Derek Wuelfrath <dwuelfrath@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;
