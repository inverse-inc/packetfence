package captiveportal::PacketFence::DynamicRouting::ModuleManager;

=head1 NAME

captiveportal::DynamicRouting::ModuleManager

=head1 DESCRIPTION

Role for modules that manage other modules

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module';

use pf::log;
use List::MoreUtils qw(firstval any);

has 'current_module' => (is => 'rw', builder => '_build_current_module', lazy => 1);

has 'module_map' => (is => 'rw', default => sub { {} });

has 'modules_order' => (is => 'rw', required => 1);

has 'completed' => (is => 'rw', builder => '_build_completed', lazy => 1);

=head2 after current_module

Set the current module in the session after setting it

=cut

after 'current_module' => sub {
    my ($self) = @_;
    $self->session->{current_module} = $self->{current_module};
};

=head2 _build_current_module

Builder to restore the current module from the session

=cut

sub _build_current_module {
    my ($self) = @_;
    return $self->session->{current_module};
}

=head2 _build_completed

Builder to restore the completed attribute from the session

=cut

sub _build_completed {
    my ($self) = @_;
    return $self->session->{completed} // 0;
}

=head2 before done

Before the module calls done, we record that we completed what had to be done here.

=cut

before 'done' => sub {
    my ($self) = @_;
    $self->session->{completed} = 1;
    $self->completed(1);
};

=head2 find_module

Find a module by its object reference

=cut

sub find_module {
    my ($self,  $module) = @_;
    return firstval { $_ eq $module } values %{$self->module_map};
}

=head2 count_modules

Count the amount of modules

=cut

sub count_modules {
    my ($self) = @_;
    return scalar(@{$self->modules_order});
}

=head2 get_module

Get a module by its index

=cut

sub get_module {
    my ($self, $index) = @_;
    return $self->module_map->{$self->modules_order->[$index]};
}

=head2 all_modules

Get all the modules

=cut

sub all_modules {
    my ($self) = @_;
    return map {
        $self->module_map->{$_}
    } @{$self->modules_order};
}

=head2 add_module

Add a module to the available ones

=cut

sub add_module {
    my ($self, $module) = @_;
    $module->renderer($self);
    die "Module ".$module->id." is not declared in the ordering." unless(any {$_ eq $module->id} @{$self->modules_order}) ;
    $self->module_map->{$module->id} = $module;
}

=head2 execute_child

Send the flow to the proper child module
- If the flow is completed, we notify our parent
- Otherwise, we look for the current module in the session
- If all of the above fail, we execute the default behavior of the module

=cut

sub execute_child {
    my ($self) = @_;
    my $module;

    if($self->completed){
        get_logger->debug("Completed module ".$self->id);
        $self->done();
    }
    elsif($self->current_module && ($module = $self->module_map->{$self->current_module})){
        get_logger->debug("Executing current module from session ".$module->id);
        $module->execute();
    }
    else {
        get_logger->debug("No current module. Executing default behavior");
        $self->default_behavior();
    }
};

=head2 default_behavior

What to do by default. In this case we execute the default module

=cut

sub default_behavior {
    my ($self) = @_;
    if($self->default_module){
        $self->default_module->execute();
    }
    else {
        $self->app->error("Cannot find any authentication mechanism to apply. Please contact your local support.");
    }
}

=head2 default_module

The default module

=cut

sub default_module {
    my ($self) = @_;
    return $self->get_module(0);
}

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

