package captiveportal::PacketFence::DynamicRouting::Module::Authentication::Choice;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::Choice

=head1 DESCRIPTION

For a choice between multiple authentication sources

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Choice';

has 'source' => (is => 'rw', isa => 'pf::Authentication::Source');

has 'custom_fields' => (is => 'rw', isa => 'ArrayRef[Str]', default => sub {[]});

with 'captiveportal::Role::MultiSource';

use pf::log;
use pf::constants;
use captiveportal::util;

=head2 display

Overriding here to check for sources AND modules to replace the MultiSource logic of checking only for sources

=cut

sub display { 
    my ($self) = @_;
    $self->count_modules > 0 
}

=head2 BUILD

Create the dynamic modules based on the sources of the module

=cut

sub BUILD {
    my ($self) = @_;
    my @sources = @{$self->sources()};

    get_logger->debug("Building Authentication Choice module using sources : ".join(',', map{$_->id} @sources) );
    push @{$self->modules_order}, (map {generate_module_id($self->id, generate_dynamic_module_id($_->id))} @sources);
    foreach my $source (@sources){
        die "Missing DynamicRouting module for source : ".$source->id unless($source->dynamic_routing_module);
        my $module = "captiveportal::DynamicRouting::Module::".$source->dynamic_routing_module;
        $self->add_module($module->new(
            id => generate_module_id($self->id, generate_dynamic_module_id($source->id)),
            description => $source->description,
            app => $self->app,
            parent => $self,
            source_id => $source->id,
            custom_fields => $self->custom_fields,
        ));
    }
}

=head2 execute_child

Validate there are sources and display a message if there are none. Otherwise, let Choice handle it

=cut

sub execute_child {
    my ($self) = @_;
    
    unless($self->count_modules){
        $self->app->error("No authentication sources found in configuration. Select another option.");
        return;
    }
    $self->SUPER::execute_child();
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

