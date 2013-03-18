package pf::config::cached::switches;
=head1 NAME

pf::config::cached::switches

=cut

=head1 DESCRIPTION

A module to provide a layer for reading a cached switches config

=cut

use pf::config::cached;
use pf::config;
use Moose;
extends 'pf::config::cached';

has '+configFile' => ( default => $switches_config_file);

sub fixupConfig {
    my ($self,$config)   = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    foreach my $section ( keys %$config ) {
        foreach my $key ( keys %{ $config->{$section} } ) {
            $config->{$section}{$key} =~ s/\s+$//;
        }
    }
    $config->{'127.0.0.1'} = {type => 'PacketFence', mode => 'production', uplink => 'dynamic', SNMPVersionTrap => '1', SNMPCommunityTrap => 'public'};
    if(exists $config->{'default'}) {
        my %default_values = %{$config->{'default'}};
        foreach my $section ( grep { $_ ne 'default' }  keys %$config ) {
            $config->{$section}  = { %default_values , %{$config->{$section}} };
        }
    }
    #Instanciate 127.0.0.1 switch

}
__PACKAGE__->meta->make_immutable;

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

