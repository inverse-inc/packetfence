package pfconfig::namespaces::resource::RolesReverseLookup;

=head1 NAME

pfconfig::namespaces::resource::RolesReverseLookup -

=head1 DESCRIPTION

pfconfig::namespaces::resource::RolesReverseLookup

=cut

use strict;
use warnings;
use pfconfig::namespaces::config::Scan;
use pfconfig::namespaces::config::AdminRoles;
use pfconfig::namespaces::config::Provisioning;
use pfconfig::namespaces::config::SelfService;
use pfconfig::namespaces::config::BillingTiers;
use Hash::Merge qw(merge);

use base 'pfconfig::namespaces::resource';

sub build {
    my ($self) = @_;
    my $configScan = pfconfig::namespaces::config::Scan->new( $self->{cache} );
    $configScan->build;
    my $configAdminRoles = pfconfig::namespaces::config::AdminRoles->new( $self->{cache} );
    $configAdminRoles->build;
    my $configProvisioning = pfconfig::namespaces::config::Provisioning->new( $self->{cache} );
    $configProvisioning->build;
    my $mergedHashed = {};
    for my $lookup ($self->lookups()) {
        $mergedHashed = merge($mergedHashed, $lookup);
    }

    return $mergedHashed;
}

sub lookups {
    my ($self) = @_;
    my $cache = $self->{cache};
    my @lookups;
    for my $module (qw(pfconfig::namespaces::config::Scan pfconfig::namespaces::config::AdminRoles pfconfig::namespaces::config::Provisioning pfconfig::namespaces::config::SelfService pfconfig::namespaces::config::BillingTiers)) {
        my $config = $module->new($cache);
        $config->build;
        my $lookup = $config->{roleReverseLookup};
        next if !defined $lookup || keys %$lookup == 0;
        push @lookups, $lookup;
    }

    return @lookups;
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
