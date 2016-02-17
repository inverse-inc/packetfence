package captiveportal::DynamicRouting::AuthModule::AuthChoice;

=head1 NAME

captiveportal::DynamicRouting::AuthModule::AuthChoice

=head1 DESCRIPTION

For a choice between multiple authentication sources

=cut

use Moose;
extends 'captiveportal::DynamicRouting::OrModule';

has 'source' => (is => 'rw');

with 'captiveportal::DynamicRouting::MultiSource';

use pf::log;
use pf::constants;
use captiveportal::DynamicRouting::util;

sub BUILD {
    my ($self) = @_;
    my @sources = @{$self->sources()};

    get_logger->debug("Building AuthChoice module using sources : ".join(',', map{$_->id} @sources) );
    $self->modules_order([map {generate_id($self->id, generate_dynamic_module_id($_->id))} @sources]);
    foreach my $source (@sources){
        die "Missing DynamicRouting module for source : ".$source->id unless($source->dynamic_routing_module);
        my $module = "captiveportal::DynamicRouting::".$source->dynamic_routing_module;
        $self->add_module($module->new(
            id => generate_id($self->id, generate_dynamic_module_id($source->id)),
            app => $self->app,
            parent => $self,
            source_id => $source->id,
        ));
    }
}

sub execute_child {
    my ($self) = @_;
    
    unless(@{$self->sources}){
        $self->app->error("No authentication sources found in configuration. Select another option.");
        return;
    }
    $self->SUPER::execute_child();
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

__PACKAGE__->meta->make_immutable;

1;

