package captiveportal::DynamicRouting::Factory;

=head1 NAME

pf::factory::firewallsso 

=cut

=head1 DESCRIPTION

pf::factory::firewallsso

The factory for creating pf::firewallsso objects

=cut

use strict;
use warnings;
use Moose;

use Module::Pluggable search_path => 'captiveportal::DynamicRouting', sub_name => 'modules' , require => 1, except => ['captiveportal::DynamicRouting::Factory', 'captiveportal::DynamicRouting::Application'];
use pfconfig::cached_hash;
use Graph;
use List::MoreUtils qw(any);
use captiveportal::DynamicRouting::util;

has 'application' => (is => 'rw', isa => 'captiveportal::DynamicRouting::Application');

has 'graph' => (is => 'rw', isa => 'Graph');

our @MODULES = __PACKAGE__->modules;
our %INSTANTIATED_MODULES;

sub factory_for { 'captiveportal::DynamicRouting' }

tie our %ConfigPortalModules, 'pfconfig::cached_hash', 'config::PortalModules';

sub build_application {
    my ($self, $application) = @_;
    $self->application($application);
    $self->graph(Graph->new);
    $self->add_to_graph($self->application->root_module_id);
    if($self->graph->is_cyclic){
        die "Profile modules graph is cyclic, this means there is an infinite loop that needs to be fixed...";
    }

    $self->instantiate_all();
    $self->create_modules_hierarchy();
}

sub instantiate_all {
    my ($self) = @_;
    $self->instantiate_child($self->application->root_module_id);
}

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

sub create_modules_hierarchy {
    my ($self) = @_;
    my @exterior = $self->graph->exterior_vertices;
    foreach my $module_id (@exterior){
        $self->add_modules_hierarchy($module_id);
    }
    $self->application->root_module($INSTANTIATED_MODULES{$self->application->root_module_id});
    
}

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

sub instantiate {
    my ($self,$id,%args) = @_;
    my $object;
    $args{id} = $id;

    my @new_modules_ids;
    foreach my $sub_module_id (@{$args{modules}}){
        push @new_modules_ids, generate_id($id, $sub_module_id);
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

sub add_to_graph {
    my ($self, $module_id) = @_;
    my $modules = $ConfigPortalModules{clean_id($module_id)}{modules};
    foreach my $sub_module_id (@$modules){
        my $u_sub_module_id = generate_id($module_id, $sub_module_id);
        $self->graph->add_path($module_id, $u_sub_module_id);
        if($ConfigPortalModules{clean_id($u_sub_module_id)}{modules}){
            $self->add_to_graph($u_sub_module_id);
        }
    }
}

sub getModuleName {
    my ($class,$name,%data) = @_;
    my $mainClass = $class->factory_for;
    my $type = $data{type};
    my $subclass = "${mainClass}::${type}";
    die "type is not defined for $name" unless defined $type;
    die "$type is not a valid type" unless any { $_ eq $subclass  } @MODULES;
    $subclass;
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


