package captiveportal::PacketFence::DynamicRouting::Factory;

=head1 NAME

captiveportal::PacketFence::DynamicRouting::Factory

=cut

=head1 DESCRIPTION

The factory for creating captiveportal::PacketFence::DynamicRouting::Module objects

=cut

use strict;
use warnings;
use Moose;

use Module::Pluggable
  search_path => 'captiveportal::DynamicRouting::Module',
  sub_name    => 'modules',
  inner       => 0,
  require     => 1;
use pfconfig::cached_hash;
use pf::constants;
use pf::util;
use Graph;
use List::MoreUtils qw(any);
use captiveportal::util;
use pf::config qw(
    %ConfigPortalModules
);
use pf::log;

has 'application' => (is => 'rw', isa => 'captiveportal::DynamicRouting::Application');

has 'graph' => (is => 'rw', isa => 'Graph', default => sub {Graph->new});

our @MODULES = modules();
our %INSTANTIATED_MODULES;

sub factory_for { 'captiveportal::DynamicRouting::Module' }

=head2 build_application

Build the application and all its modules

=cut

sub build_application {
    my ($self, $application) = @_;
    eval {
        $self->application($application);
        $self->add_to_graph($self->application->root_module_id);

        $self->instantiate_all();
        $self->create_modules_hierarchy();
    };
    if($@){
        get_logger->error("Can't build application from configuration : $@");
        return $FALSE;
    }
    return $TRUE;
}

=head2 instantiate_all

Instantiate all the Application Module objects so they can be configured after

=cut

sub instantiate_all {
    my ($self) = @_;
    my $timer = pf::StatsD::Timer->new({sample_rate => 0.05, level => 7});
    $self->instantiate_child($self->application->root_module_id);
}

=head2 instantiate_child

Instantiate a module and all of its child modules

=cut

sub instantiate_child {
    my ($self, $module_id, $parent_id) = @_;

    my %args = %{$ConfigPortalModules{clean_id($module_id)}};
    if($parent_id){
        $args{parent} = $INSTANTIATED_MODULES{$parent_id};
    }

    my $module = $self->instantiate($module_id, %args);
    $INSTANTIATED_MODULES{$module_id} = $module;

    my @edges = $self->graph->edges_from($module_id);

    foreach my $edge (@edges){
        $self->instantiate_child($edge->[1], $module_id);
    }

}

=head2 create_modules_hierarchy

Go through the graph from the bottom to the top to set the parent in the modules

=cut

sub create_modules_hierarchy {
    my ($self) = @_;
    my @exterior = $self->graph->exterior_vertices;
    foreach my $module_id (@exterior){
        $self->add_modules_hierarchy($module_id);
    }
    $self->application->root_module($INSTANTIATED_MODULES{$self->application->root_module_id});

}

=head2 add_modules_hierarchy

Go through the graph paths up to the root to set the childs in the objects

=cut

sub add_modules_hierarchy {
    my ($self, $module_id, $child_id) = @_;
    my $module = $INSTANTIATED_MODULES{$module_id};

    if($child_id){
        $module->add_module($INSTANTIATED_MODULES{$child_id});
    }

    my @edges = $self->graph->edges_to($module_id);
    foreach my $edge (@edges){
        my $parent_id = $edge->[0];
        $self->add_modules_hierarchy($parent_id, $module_id);
    }
}

=head2 instantiate

Instantiate a module from the configuration

=cut

sub instantiate {
    my ($self,$id,%args) = @_;
    my $object;
    $args{id} = $id;

    my @new_modules_ids;
    foreach my $sub_module_id (@{$args{modules}}){
        push @new_modules_ids, generate_module_id($id, $sub_module_id);
    }
    $args{modules} = \@new_modules_ids;

    # The modules are inserted by the factory
    $args{modules_order} = $args{modules};
    delete $args{modules};

    if (%args) {
        my $subclass = $self->getModuleName($id,%args);
        $object = $subclass->new(%args, app => $self->application);
    }
    return $object;
}

=head2 add_to_graph

Add a module and all of its child modules to the graph
Will die if the graph is cyclic (detected by seeing if the same module ID is there twice in the unique ID that contains the full path)
  ex : root_module+this_will_cycle+some_module+this_will_cycle

=cut

sub add_to_graph {
    my ($self, $module_id) = @_;
    my $modules = $ConfigPortalModules{clean_id($module_id)}{modules};
    foreach my $sub_module_id (@$modules){
        my $u_sub_module_id = generate_module_id($module_id, $sub_module_id);
        if(id_is_cyclic($u_sub_module_id)){
            die "Modules are cyclic which is not allowed. Detected on ID : $u_sub_module_id \n";
        }
        $self->graph->add_path($module_id, $u_sub_module_id);
        if($ConfigPortalModules{clean_id($u_sub_module_id)}{modules}){
            $self->add_to_graph($u_sub_module_id);
        }
    }
}

=head2 getModuleName

Get the module class name from the type in the configuration

=cut

sub getModuleName {
    my ($class,$name,%data) = @_;
    my $mainClass = $class->factory_for;
    my $type = $data{type};
    my $subclass = "${mainClass}::${type}";
    die "type is not defined for $name" unless defined $type;
    die "$type is not a valid type" unless any { $_ eq $subclass  } @MODULES;
    $subclass;
}

=head2 check_cyclic

Given an ID, check if there is a cycle in its childs

=cut

sub check_cyclic {
    my ($self, $id) = @_;
    $self->graph(Graph->new);
    eval {
        $self->add_to_graph($id);
    };
    if($@){
        return ($FALSE, $@);
    }
    return ($TRUE);
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


