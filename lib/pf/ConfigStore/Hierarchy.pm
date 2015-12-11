package pf::ConfigStore::Hierarchy;

=head1 NAME

pf::ConfigStore::Hierarchy

=cut

=head1 DESCRIPTION

Allows to create a hierarchy between configuration sections

=cut

use Moo::Role;

sub globalConfigStore { return $_[0] }

sub topLevelGroup { return "default" }

sub parentAttribute { return "group" }

sub _inherit_from {
    my ($self, $switch) = @_;
    my $group = $switch->{$self->parentAttribute} ? $self->_formatGroup($switch->{group}) : $self->topLevelGroup;
    return $group;
}

sub _formatGroup {
    my ($self, $group) = @_;
    return $group;
}

sub parentConfigRaw {
    my ($self, $id) = @_;
    return $self->fullConfigRaw($self->_inherit_from($self->read($id)));
}

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

sub fullConfig {
    my ($self, $id) = @_;
    my $config = $self->fullConfigRaw($id);
    return $self->cleanupAfterRead($config);
}

sub parentConfig {
    my ($self, $id) = @_;
    my $config = $self->parentConfigRaw($id);
    return $self->cleanupAfterRead($config);
}

=back

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

