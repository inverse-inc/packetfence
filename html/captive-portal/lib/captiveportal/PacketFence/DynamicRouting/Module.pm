package captiveportal::PacketFence::DynamicRouting::Module;

=head1 NAME

DynamicRouting::Module

=head1 DESCRIPTION

Base Module for Dynamic Routing

=cut

use Moose;
use pf::log;
use pf::config;
use Hash::Merge qw(merge);
use List::MoreUtils qw(any);
use pf::node;
use pf::person;

has id => (is => 'ro', required => 1);

has description => (is => 'rw');

has session => (is => 'rw', builder => '_build_session');

has new_node_info => (is => 'rw', builder => '_build_new_node_info', lazy => 1);

has app => (is => 'ro', required => 1, isa => 'captiveportal::DynamicRouting::Application');

has parent => (is => 'ro', required => 1, isa => 'captiveportal::DynamicRouting::Module');

has username => (is => 'rw', builder => '_build_username', lazy => 1);

has renderer => (is => 'rw');

=head2 display

Defines whether or not a module should be displayed

=cut

sub display {$TRUE}

=head2 _build_username

Builder for the username (to restore from the session)

=cut

sub _build_username {
    my ($self) = @_;
    return $self->app->session->{username};
}

=head2 after username

Set the username in the session and in the new_node_info after setting it

=cut

after 'username' => sub {
    my ($self) = @_;
    get_logger->info("User ".$self->{username}." has authenticated on the portal.");
    $self->new_node_info->{pid} = $self->{username};
    $self->app->session->{username} = $self->{username};
    if(!person_exist($self->{username})){
        person_add($self->{username});
    }
};

=head2 _build_session

Build the module specific session

=cut

sub _build_session {
    my ($self) = @_;
    my $module_session_id = "module_".$self->id;
    $self->app->session()->{$module_session_id} = $self->app->session()->{$module_session_id} // {};
    my $module_session = $self->app->session()->{$module_session_id};
    return $module_session;
}

=head2 _build_new_node_info

Build the new_node_info that will be used to update the node at the end of the session

=cut

sub _build_new_node_info {
    my ($self) = @_;
    $self->app->session()->{"new_node_info"} //= {};
    return $self->app->session()->{"new_node_info"};
}

=head2 pretty_class_name

Return this class name in a prettier way

=cut

sub pretty_class_name {
    my ($self) = @_;
    my $name = ref($self);
    $name =~ s/::/-/g;
    $name =~ s/^captiveportal-DynamicRouting-//g;
    return $name;
}

=head2 pretty_id

Return this module ID in a prettier way

=cut

sub pretty_id {
    my ($self) = @_;
    my $name = $self->id;
    $name =~ s/\+/\-/g;
    return $name;
}

=head2 node_info

Get the node_info merged with the new_node_info

=cut

sub node_info {
    my ($self) = @_;
    Hash::Merge::set_behavior( 'RIGHT_PRECEDENT' );
    my $node_info = merge(node_view($self->current_mac), $self->new_node_info, {username => $self->username} );
    return $node_info;
}

=head2 current_mac

The MAC address for the current request

=cut

sub current_mac {
    my ($self) = @_;
    return $self->app->current_mac;
}

=head2 current_ip

The IP address for the current request

=cut

sub current_ip {
    my ($self) = @_;
    return $self->app->current_ip;
}

=head2 _release_args

The arguments that are used when releasing a device on the network

=cut

sub _release_args {
    my ($self) = @_;
    return {
        timer         => $Config{'trapping'}{'redirtimer'},
        destination_url  => $self->app->session->{destination_url},
        initial_delay => $CAPTIVE_PORTAL{'NET_DETECT_INITIAL_DELAY'},
        retry_delay   => $CAPTIVE_PORTAL{'NET_DETECT_RETRY_DELAY'},
        external_ip => $Config{'captive_portal'}{'network_detection_ip'},
        auto_redirect => $Config{'captive_portal'}{'network_detection'},
        image_path => $Config{'captive_portal'}{'image_path'},
    };
}

=head2 execute

Execute this module flow.
Will check if the path can be used in this module
Will notify parent that he is the current module
Then forwards it to the module specific actions

=cut

sub execute {
    my ($self) = @_;
    get_logger->trace(sub{"Executing ".$self->id});
    if($self->parent){
        $self->parent->current_module($self->id);
    }

    unless($self->path_is_allowed('/'.$self->app->request->path)){
        get_logger->debug('/'.$self->app->request->path." is not allowed in module : ".$self->id);
        $self->app->redirect("/captive-portal");
        return;
    }

    $self->execute_child();
}

=head2 allowed_urls

The URLs that are allowed in this module

=cut

sub allowed_urls {[]}

=head2 path_is_allowed

Whether or not the current request path is allowed in this module

=cut

sub path_is_allowed {
    my ($self, $path) = @_;
    get_logger->trace(sub { use Data::Dumper ; "Allowed URLs for $path are : ".Dumper($self->allowed_urls)});
    if(!@{$self->allowed_urls} || $path eq "/captive-portal" || (any {$_ eq $path} @{$self->allowed_urls}) || ($self->can('path_method') && $self->path_method($path))){
        return $TRUE;
    }
    else {
        return $FALSE;
    }
}

=head2 execute_child

Module specific execution. Meant to be overriden in subclasses

=cut

sub execute_child {
    inner();
}

=head2 execute_actions

Actions to be executed when the module has been completed.

=cut

sub execute_actions {
    # implement me in subclasses
    return $TRUE;
}

=head2 done

Executes the actions and notifies parent that the module has been completed

=cut

sub done {
    my ($self) = @_;
    unless($self->execute_actions()){
        get_logger->warn("Execute actions of module ".$self->id." did not succeed.");
        # we give a generic message if there is none in the flash error
        $self->app->flash->{error} = "Could not execute actions." unless($self->app->flash->{error});
        $self->app->redirect("/captive-portal");
        return;
    }
    $self->parent->next();
}

=head2 next

What to do after a child module (if any) has completed

=cut

sub next {
    my ($self) = @_;
    $self->done();
}

=head2 render

To render a template using the current renderer of the module

=cut

sub render {
    my ($self, @params) = @_;
    if($self->renderer){
        $self->renderer->render(@params);
    }
    else {
        $self->app->render(@params);
    }
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

