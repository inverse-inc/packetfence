package pf::ConfigStore::Role::ReverseLookup;

=head1 NAME

pf::ConfigStore::Role::ReverseLookup -

=cut

=head1 DESCRIPTION

pf::ConfigStore::Role::ReverseLookup

=cut

use strict;
use warnings;
use Moo::Role;
use pfconfig::cached_hash;
tie our %ProfileReverseLookup, 'pfconfig::cached_hash', 'resource::ProfileReverseLookup';
tie our %PortalModuleReverseLookup, 'pfconfig::cached_hash', 'resource::PortalModuleReverseLookup';
tie our %ProvisioningReverseLookup, 'pfconfig::cached_hash', 'resource::ProvisioningReverseLookup';
tie our %SwitchReverseLookup, 'pfconfig::cached_hash', 'resource::SwitchReverseLookup';

sub isInProfile {
    my ($self, $namespace, $id) = @_;
    return exists $ProfileReverseLookup{$namespace}{$id};
}

sub isInPortalModules {
    my ($self, $namespace, $id) = @_;
    return exists $PortalModuleReverseLookup{$namespace}{$id};
}

sub isInProvisioning {
    my ($self, $namespace, $id) = @_;
    return exists $ProvisioningReverseLookup{$namespace}{$id};
}

sub isInSwitch {
    my ($self, $namespace, $id) = @_;
    return exists $SwitchReverseLookup{$namespace}{$id};
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
