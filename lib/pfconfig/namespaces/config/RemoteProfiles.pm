package pfconfig::namespaces::config::RemoteProfiles;

=head1 NAME

pfconfig::namespaces::config::RemoteProfiles

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::RemoteProfiles

This module creates the configuration hash associated to remote_profiles.conf

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw(
    $remote_profiles_config_file
    $remote_profiles_default_config_file
);

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file}            = $remote_profiles_config_file;
    $self->{default_section} = "default";
    $self->{child_resources} = [ "resource::remote_profiles_keys", "FilterEngine::RemoteProfile" ];
    my $defaults = pf::IniFiles->new(-file => $remote_profiles_default_config_file);
    $self->{added_params}{'-import'} = $defaults;
}

sub build_child {
    my ($self) = @_;
    my @uri_filters;
    my %profiles = %{ $self->{cfg} };
    $self->cleanup_whitespaces( \%profiles );

    while (my ($key, $item) = each %profiles ) {
        $self->cleanup_after_read( $key, $item );
    }

    return \%profiles;
}

sub cleanup_after_read {
    my ( $self, $id, $data ) = @_;
    $self->expand_list( $data, qw(allow_communication_to_roles) );
    $data->{additional_domains_to_resolve} = [split(/\n/, $data->{additional_domains_to_resolve})];
    $data->{routes} = [split(/\n/, $data->{routes})];
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


