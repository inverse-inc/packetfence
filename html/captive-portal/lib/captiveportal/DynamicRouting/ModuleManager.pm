package captiveportal::DynamicRouting::ModuleManager;

=head1 NAME

captiveportal::DynamicRouting::ModuleManager

=head1 DESCRIPTION

Role for modules that manage other modules

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module';

has 'current_module' => (is => 'rw', builder => '_build_current_module', lazy => 1);

has 'modules' => (
    traits  => ['Array'], 
    isa => 'ArrayRef[captiveportal::DynamicRouting::Module]', 
    default => sub { [] }, 
    handles => {
        _add_module => 'push',
        all_modules => 'elements',
        find_module => 'first',
        get_module => 'get',
        count_modules => 'count',
    },
);

has 'module_map' => (is => 'rw', default => sub { {} });

has 'completed' => (is => 'rw', builder => '_build_completed', lazy => 1);

after 'current_module' => sub {
    my ($self) = @_;
    $self->session->{current_module} = $self->{current_module};  
};

sub _build_current_module {
    my ($self) = @_;
    return $self->session->{current_module};
}

sub _build_completed {
    my ($self) = @_;
    return $self->session->{completed} // 0;
}

before 'done' => sub {
    my ($self) = @_;
    $self->session->{completed} = 1;
    $self->completed(1);
};

sub add_module {
    my ($self, $module) = @_;
    $module->renderer($self);
    $self->_add_module($module);
    $self->module_map->{$module->id} = $module;
}

sub execute_child {
    my ($self) = @_;
    my $module;

    if($self->completed){
        $self->done();
    }
    elsif($self->current_module && ($module = $self->module_map->{$self->current_module})){
        $module->execute();
    }
    elsif ($module = $self->default_module){
        $module->execute;
    }
    else {
        $self->done();
    }
}

sub default_module {
    my ($self) = @_;
    return $self->get_module(0);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

