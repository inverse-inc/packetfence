package pfconfig::namespaces::config::AdminRoles;

=head1 NAME

pfconfig::namespaces::config::AdminRoles

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::AdminRoles

This module creates the configuration hash associated to admin_roles.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw($admin_roles_config_file);
use pf::constants::admin_roles;

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $admin_roles_config_file;
    $self->{child_resources} = [ qw(resource::RolesReverseLookup) ];
}

sub build_child {
    my ($self) = @_;

    my %ADMIN_ROLES = %{ $self->{cfg} };

    $self->cleanup_whitespaces( \%ADMIN_ROLES );
    foreach my $data ( values %ADMIN_ROLES ) {
        my $actions = delete $data->{actions} || '';
        my %action_data = map { $_ => undef } split /\s*,\s*/, $actions;
        $data->{ACTIONS} = \%action_data;
    }
    $ADMIN_ROLES{NONE}{ACTIONS} = {};
    $ADMIN_ROLES{ALL}{ACTIONS} = { map { $_ => undef } @pf::constants::admin_roles::ADMIN_ACTIONS };
    $ADMIN_ROLES{ALL_PF_ONLY}{ACTIONS} = { map { $_ => undef } grep {$_ !~ /^SWITCH_LOGIN_/} @pf::constants::admin_roles::ADMIN_ACTIONS };

    $self->{roleReverseLookup} = {};
    while (my ($key, $val) = each %ADMIN_ROLES) {
        $self->updateRoleReverseLookup($key, $val, 'admin_roles', qw(allowed_roles allowed_node_roles));
    }

    return \%ADMIN_ROLES;

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

