package pf::ConfigStore::Role::TenantID;

=head1 NAME

pf::ConfigStore::Role::TenantID -

=cut

=head1 DESCRIPTION

Role to scope a config store by a tenant

=cut

use strict;
use warnings;
use Moo::Role;
use pf::config::tenant;

=head2 _Section

_Section

=cut

around _Sections => sub {
    my $orig = shift;
    my $self = shift;
    my $tenant_id = pf::config::tenant::get_tenant();
    return grep { s/^\Q$tenant_id\E // } $orig->($self, @_);
};

=head2 _formatSectionName

=cut

around _formatSectionName => sub {
    my $orig = shift;
    my $self = shift;
    return pf::config::tenant::get_tenant() . " " . $orig->($self, @_);
};

=head2 _cleanupId

=cut

around _cleanupId => sub {
    my $orig = shift;
    my ($self, $id) = @_;
    my $tenant_id = pf::config::tenant::get_tenant();
    $id =~ s/^\Q$tenant_id\E //g;
    return $orig->($self, $id);
};

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
