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
}

sub build_child {
    my ($self) = @_;

    my %ADMIN_ROLES = %{ $self->{cfg} };

    $self->cleanup_whitespaces( \%ADMIN_ROLES );
    foreach my $data ( values %ADMIN_ROLES ) {
        my $actions = $data->{actions} || '';
        my %action_data = map { $_ => undef } split /\s*,\s*/, $actions;
        $data->{ACTIONS} = \%action_data;
    }
    $ADMIN_ROLES{NONE}{ACTIONS} = {};
    $ADMIN_ROLES{ALL}{ACTIONS} = { map { $_ => undef } @pf::constants::admin_roles::ADMIN_ACTIONS };
    $ADMIN_ROLES{ALL_PF_ONLY}{ACTIONS} = { map { $_ => undef } grep {$_ !~ /^SWITCH_LOGIN_/} @pf::constants::admin_roles::ADMIN_ACTIONS };

    foreach my $key ( keys %ADMIN_ROLES ) {
        $self->cleanup_after_read( $key, $ADMIN_ROLES{$key} );
    }

    return \%ADMIN_ROLES;

}

sub cleanup_after_read {
    my ( $self, $id, $item ) = @_;

    delete $item->{actions};

    # Seems we don't need to do it for the HASH, but I'll leave it here
    # just in case. Remove this when confirmed everything works fine
    #    $self->expand_list($item, qw(actions allowed_roles allowed_access_levels));
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

