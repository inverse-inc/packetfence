package pfconfig::namespaces::config::SelfService;

=head1 NAME

pfconfig::namespaces::config::SelfService

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::SelfService

This module creates the configuration hash associated to self_service.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw($self_service_config_file $self_service_default_config_file);
use pf::util;

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file} = $self_service_config_file;
    $self->{child_resources} = [ qw(resource::RolesReverseLookup) ];
    my $defaults = Config::IniFiles->new( -file => $self_service_default_config_file );
    $self->{added_params}->{'-import'} = $defaults;
}

sub build_child {
    my ($self) = @_;

    my %tmp_cfg = %{ $self->{cfg} };

    while (my ($key, $item) = each %tmp_cfg ) {
        $self->cleanup_after_read( $key, $item );
        $self->updateRoleReverseLookup($key, $item, 'selfservice', qw(roles_allowed_to_unregister device_registration_roles));
    }

    return \%tmp_cfg;

}

sub cleanup_after_read {
    my ( $self, $id, $data ) = @_;
    $self->expand_list( $data, qw(device_registration_allowed_devices roles_allowed_to_unregister) );
    $data->{device_registration_access_duration} = $data->{device_registration_access_duration} ? normalize_time($data->{device_registration_access_duration}) : 0;
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

