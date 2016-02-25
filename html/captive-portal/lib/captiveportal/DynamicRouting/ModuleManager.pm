package captiveportal::DynamicRouting::ModuleManager;

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

after 'current_module' => sub {
    my ($self) = @_;
    $self->app->user_cache->set($self->id."_current_module", $self->{current_module});
};

sub _build_current_module {
    my ($self) = @_;
    return $self->app->user_cache->get($self->id."_current_module");
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

sub find_module {
    my ($self,  $module) = @_;
    return firstval { $_ eq $module } values %{$self->module_map};
}

sub count_modules {
    my ($self) = @_;
    return scalar(@{$self->modules_order});
}

sub get_module {
    my ($self, $index) = @_;
    return $self->module_map->{$self->modules_order->[$index]};
}

sub all_modules {
    my ($self, $index) = @_;
    return map {
        $self->module_map->{$_}
    } @{$self->modules_order};
}

sub add_module {
    my ($self, $module) = @_;
    $module->renderer($self);
    die "Module ".$module->id." is not declared in the ordering." unless(any {$_ eq $module->id} @{$self->modules_order}) ;
    $self->module_map->{$module->id} = $module;
}

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

sub default_behavior {
    my ($self) = @_;
    $self->default_module->execute();
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

