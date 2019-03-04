package pf::ConfigStore::Realm;
=head1 NAME

pf::ConfigStore::Realm
Store Realm configuration

=cut

=head1 DESCRIPTION

pf::ConfigStore::Realm

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw(
    $realm_config_file
    $realm_default_config_file
);
extends 'pf::ConfigStore';
with qw(pf::ConfigStore::Role::TenantID);

sub configFile { $realm_config_file }

sub importConfigFile { $realm_default_config_file }

sub pfconfigNamespace {'config::Realm'}

=head2 cleanupAfterRead

Clean up realm data

=cut

sub cleanupAfterRead {
    my ($self, $id, $profile) = @_;
    $self->expand_list($profile, $self->_fields_expanded);
    # This can be an array if it's fresh out of the file. We make it separated by newlines so it works fine the frontend
    if(ref($profile->{options}) eq 'ARRAY'){
        $profile->{options} = $self->join_options($profile->{options});
    }
}

=head2 cleanupBeforeCommit

Clean data before update or creating

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $profile) = @_;
    $self->flatten_list($profile, $self->_fields_expanded);
}

=head2 _fields_expanded

=cut

sub _fields_expanded {
    return qw(categories radius_acct radius_auth);
}


=head2 join_options

Join options in array with a newline

=cut

sub join_options {
    my ($self,$options) = @_;
    return join("\n",@$options);
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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

