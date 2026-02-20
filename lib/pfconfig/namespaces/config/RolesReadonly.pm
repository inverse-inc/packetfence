package pfconfig::namespaces::config::RolesReadonly;

=head1 NAME

pfconfig::namespaces::config::RolesReadonly

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::RolesReadonly

This module creates the configuration hash associated to roles_readonly.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw($roles_readonly_config_file);
use pf::util qw(isenabled);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $roles_readonly_config_file;
}

sub build_child {
    my ($self) = @_;
    my %tmp_cfg = %{ $self->{cfg} };
    my %result;
    while ( my ($name, $data) = each %tmp_cfg ) {
        if (isenabled($data->{readonly})) {
            $result{$name} = 1;
        }
    }

    return \%result;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
