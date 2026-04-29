package pf::ConfigStore::Roles;
=head1 NAME

pf::ConfigStore::Roles

=cut

=head1 DESCRIPTION

Store and manipulate roles configuration

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw($roles_config_file $roles_default_config_file);
use pf::nodecategory;
use pf::config::cluster;
use pf::constants;
use pf::config qw(%Config);
use pfconfig::manager;
use pfconfig::git_storage;
extends 'pf::ConfigStore';

sub configFile { $roles_config_file };
sub importConfigFile { $roles_default_config_file }

sub pfconfigNamespace {'config::Roles'}

=head2 cleanupAfterRead

Clean up realm data

=cut

sub cleanupAfterRead {
    my ($self, $id, $data) = @_;
    # This can be an array if it's fresh out of the file. We make it separated by newlines so it works fine the frontend
    if(ref($data->{acls}) eq 'ARRAY'){
        $data->{acls} = join("\n", @{$data->{acls}}, "");
    }
}

=head2 cleanupBeforeCommit

Default `acls` to an empty string when missing so pfconfig's generic-copy
inheritance does not pull the parent's ACLs into the child's flattened
node_category row (runtime walk in Switch.pm handles the ACL fallback
instead).

For `parent_id`: on CREATE (section does not yet exist) when the payload
omits the key, always materialize the value:
  * if `advanced.default_role_parent_id` is set (and points at an
    existing role other than this one), use it.
  * otherwise, write an explicit `parent_id=` (empty).
This "locks in" a role's parent at creation time so a later change to
`advanced.default_role_parent_id` cannot retroactively re-parent the
already-saved role. On UPDATE, never inject — preserve whatever is in
the existing config.

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $assignments) = @_;
    $assignments->{acls} = ''
        unless defined $assignments->{acls};

    # Defensive backstop only. The UnifiedApi Roles controller's
    # cleanupItemForCreate/cleanupItemForUpdate hooks resolve the
    # advanced.default_role_parent_id semantics from the raw payload
    # (which still distinguishes "key missing" from "key present + null").
    # Anything still undef here on create came from a non-API caller —
    # persist as the explicit empty lock so the pfconfig runtime
    # fallback won't auto-fill it.
    if (!defined $assignments->{parent_id}
        && !$self->cachedConfig->SectionExists($id)) {
        $assignments->{parent_id} = '';
    }
}

=head2

=cut

sub readDefaults {
    my ($self) = @_;
    my $default_section = $Config{advanced}{default_role_parent_id};
    if (!defined $default_section || $default_section eq '' ) {
        return undef;
    }

    my $data = $self->read($default_section, 'id');
    if ($data) {
        $data->{id} = undef;
        $data->{parent_id} = '' unless defined $data->{parent_id};
    }

    return $data;
}


=head2 parentSections

Return the parent role section so values from parent_id can be inherited.

=cut

sub parentSections {
    my ($self, $id, $item) = @_;
    my $parent_id = $item->{parent_id} // $self->cachedConfig->val($id, 'parent_id') // '';
    my $default_section = $self->default_section;
    return if defined $default_section && $id eq $default_section;
    my @parents;
    my %seen = ($id => 1);
    while (defined $parent_id && length $parent_id && !$seen{$parent_id} && (!defined $default_section || $default_section ne $parent_id)) {
        push @parents, $parent_id;
        $seen{$parent_id} = 1;
        $parent_id = $self->cachedConfig->val($parent_id, 'parent_id');
    }

    return @parents, $self->SUPER::parentSections($id, $item);
}


=item commitPfconfig

Override to use light expire instead of hard expire.
The config will be rebuilt once in commit() via cache_resource,
avoiding a redundant full rebuild from the parent's hard expire.

=cut

sub commitPfconfig {
    my ($self) = @_;
    if (!defined($self->pfconfigNamespace)) {
        pf::log::get_logger->warn("Can't expire pfconfig in " . ref($self) . " because the pfconfig namespace is not defined.");
        return ($TRUE, undef);
    }

    if ($cluster_enabled) {
        return $self->SUPER::commitPfconfig();
    }

    my $manager = pfconfig::manager->new;
    # Light expire: updates control file timestamps and cascades to
    # children/overlayed without doing a full rebuild. The single
    # necessary rebuild happens in commit() below.
    $manager->expire($self->pfconfigNamespace, 1);
    if (pfconfig::git_storage->is_enabled) {
        return $self->commitGitStorage();
    }

    return ($TRUE, undef);
}

=item commit

Repopulate the node_category table after commiting

=cut

sub commit {
    my ($self) = @_;
    my ($result, $error) = $self->SUPER::commit();
    if ($result) {
        pf::log::get_logger->info("commiting via Roles configstore");
        my $manager = pfconfig::manager->new;
        # Single build: rebuilds from disk, caches in L2, and notifies pfconfig
        my $config = $manager->cache_resource("config::Roles");
        nodecategory_populate_from_config($config);
    }
    return ($result, $error);
}

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

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


