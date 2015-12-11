package pf::ConfigStore::Hierarchy;

use Moo::Role;

sub globalConfigStore { return $_[0] }

sub topLevelGroup { return "default" }

sub _inherit_from {
    my ($self, $switch) = @_;
    my $group = $switch->{group} ? $switch->{group} : $self->topLevelGroup;
    return $self->_formatGroup($group);
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

1;

