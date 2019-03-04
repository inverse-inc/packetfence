package pf::ConfigStore::Hierarchy;

=head1 NAME

pf::ConfigStore::Hierarchy

=cut

=head1 DESCRIPTION

Allows to create a hierarchy between configuration sections

=cut

use Moo::Role;

=head2 globalConfigStore

Config store that contains both the groups and the childs

=cut

sub globalConfigStore { return $_[0] }

=head2 topLevelGroup

The top level group which cannot have any parent
Behaves like default_section where all groups + childs inherit from this by default

=cut

sub topLevelGroup { return "default" }

=head2 parentAttribute

The configuration attribute that allows to find the parent of a section

=cut

sub parentAttribute { return "group" }

=head2 _inherit_from

Find the section id to inherit from

=cut

sub _inherit_from {
    my ($self, $config) = @_;
    my $group = $config->{$self->parentAttribute} ? $self->_formatGroup($config->{group}) : $self->topLevelGroup;
    return $group;
}

=head2 _formatGroup

Format the ID of a group into the ID it should be in the globalConfigStore

=cut

sub _formatGroup {
    my ($self, $group) = @_;
    return $group;
}

=head2 parentConfigRaw

Get the configuration of the group the section is inheriting from

=cut

sub parentConfigRaw {
    my ($self, $id) = @_;
    return $self->fullConfigRaw($self->_inherit_from($self->read($id)));
}

=head2 fullConfigRaw

Get the full config of a section (including inherited properties)

=cut

sub fullConfigRaw {
    my ($self, $id) = @_;
    
    my $cs = $self->globalConfigStore;
    if($id ne $self->topLevelGroup){
        my $switch = $self->readRaw($id);
        my $parent_config = $self->fullConfigRaw($self->_inherit_from($switch));

        while (my ($key, $value) = each %$parent_config){
            if(!defined($switch->{$key})){
                $switch->{$key} = $value;
            }
        }
        return $switch;
    }
    else {
        return $cs->readRaw($id);
    }
}

=head2 fullConfig

Like fullConfigRaw but with cleanupAfterRead executed after

=cut

sub fullConfig {
    my ($self, $id) = @_;
    my $config = $self->fullConfigRaw($id);
    $self->cleanupAfterRead($id, $config);
    return $config;
}

=head2 parentConfig

Like parentConfigRaw but with cleanupAfterRead executed after

=cut

sub parentConfig {
    my ($self, $id) = @_;
    my $config = $self->parentConfigRaw($id);
    $self->cleanupAfterRead($id, $config);
    return $config;
}

=head2 members

Find the members of a group by ID

=cut

sub members {
    my ($self, $id, $idKey) = @_;
    my @values = $self->globalConfigStore->search($self->parentAttribute, $id, $idKey);
    return @values;
}

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

