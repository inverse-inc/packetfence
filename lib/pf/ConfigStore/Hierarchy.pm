package pf::ConfigStore::Hierarchy;

use Moo::Role;

sub rawConfigStore { return $_[0] }

sub topLevelGroup { return "default" }

sub _inherit_from {
    my ($self, $switch) = @_;
    return $switch->{group} ? "group ".$switch->{group} : "default";
}

sub parent_config_raw {
    my ($self, $id) = @_;
    return $self->full_config_raw($self->_inherit_from($self->read($id)));
}

sub full_config_raw {
    my ($self, $id) = @_;
    
    my $cs = $self->rawConfigStore;
    if($id ne $self->topLevelGroup){
        my $switch = $cs->read_raw($id);
        my $parent_config = $cs->full_config_raw($self->_inherit_from($switch), $cs->read_raw($self->_inherit_from($switch)));

        while (my ($key, $value) = each %$parent_config){
            if(!defined($switch->{$key})){
                $switch->{$key} = $value;
            }
        }
        return $switch;
    }
    else {
        return $cs->read_raw($id);
    }
}

1;

