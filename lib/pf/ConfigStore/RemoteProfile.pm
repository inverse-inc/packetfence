package pf::ConfigStore::RemoteProfile;
=head1 NAME

pf::ConfigStore::RemoteProfile
Store RemoteProfile configuration

=cut

=head1 DESCRIPTION

pf::ConfigStore::RemoteProfile

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw(
    $remote_profiles_config_file
    $remote_profiles_default_config_file
);
extends 'pf::ConfigStore';

sub configFile { $remote_profiles_config_file }

sub importConfigFile { $remote_profiles_default_config_file }

sub default_section { 'default' }

sub pfconfigNamespace {'config::RemoteProfiles'}

=head2 cleanupBeforeCommit

Clean data before update or creating

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $profile) = @_;
    $self->flatten_list($profile, $self->_fields_expanded);

    if (defined $profile->{advanced_filter}) {
        $self->flattenCondition($profile, 'advanced_filter');
    }
}

=head2 _fields_expanded

=cut

sub _fields_expanded {
    return qw(allow_communication_to_roles);
}

sub cleanupAfterRead {
    my ($self, $id, $profile) = @_;
    $self->expand_list($profile, $self->_fields_expanded);
    $self->adjustArrayParam($profile, "additional_domains_to_resolve");
    $self->adjustArrayParam($profile, "routes");

    if ($profile->{advanced_filter}) {
        $self->expandCondition($profile, 'advanced_filter');
    } else {
        $profile->{advanced_filter} = undef;
    }
}

sub adjustArrayParam {
    my ($self, $profile, $param) = @_;
    # This can be an array if it's fresh out of the file. We make it separated by newlines so it works fine the frontend
    if(ref($profile->{$param}) eq 'ARRAY'){
        $profile->{$param} = join("\n", @{$profile->{$param}});
    }
}


__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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

