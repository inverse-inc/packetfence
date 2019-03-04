package pf::ConfigStore::AdminRoles;

=head1 NAME

pf::ConfigStore::AdminRoles add documentation

=cut

=head1 DESCRIPTION

pf::ConfigStore::AdminRoles

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moo;
use namespace::autoclean;
use pf::file_paths qw($admin_roles_config_file);
extends 'pf::ConfigStore';

sub expandableParams { return (qw(actions allowed_roles allowed_access_levels allowed_node_roles allowed_actions)); }

sub configFile { $admin_roles_config_file }

sub pfconfigNamespace { 'config::AdminRoles' }

=head2 cleanupAfterRead

Expand list of actions

=cut

sub cleanupAfterRead {
    my ($self, $id, $item) = @_;
    $self->expand_list($item, $self->expandableParams);
}

=head2 cleanupBeforeCommit

Flatten list of actions before updating or creating

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $item) = @_;
    $self->flatten_list($item, $self->expandableParams);
}



__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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

