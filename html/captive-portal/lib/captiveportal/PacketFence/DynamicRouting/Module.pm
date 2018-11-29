package captiveportal::PacketFence::DynamicRouting::Module;

=head1 NAME

DynamicRouting::Module

=head1 DESCRIPTION

Base Module for Dynamic Routing

=cut

use Moose;
use pf::log;
use pf::constants qw($TRUE $FALSE $default_pid);
use pf::config qw(
    %Config
    %CAPTIVE_PORTAL
);
use Hash::Merge qw(merge);
use List::MoreUtils qw(any);
use pf::node;
use pf::person;
use captiveportal::Base::Actions;
use captiveportal::DynamicRouting::Detach;

has id => (is => 'ro', required => 1);

has description => (is => 'rw');

has session => (is => 'rw', builder => '_build_session');

has new_node_info => (is => 'rw', builder => '_build_new_node_info', lazy => 1);

has app => (is => 'ro', required => 1, isa => 'captiveportal::DynamicRouting::Application');

has parent => (is => 'ro', required => 1, isa => 'captiveportal::DynamicRouting::Module');

has username => (is => 'rw', builder => '_build_username', lazy => 1);

has renderer => (is => 'rw');

has 'actions' => ('is' => 'rw', isa => 'HashRef', default => sub {{}});

=head2 BUILD

Override BUILD method to validate the actions for the module

=cut

sub BUILD {
    my ($self) = @_;
    my %available_actions = map { $_ => 1 } @{$self->available_actions};
    while(my ($action, $params) = each %{$self->actions}){
        unless($available_actions{$action}){
            get_logger->error("Action $action is not allowed in module ".$self->id.". It will be ignored.");
            delete $self->actions->{$action};
        }
    }
}

=head2 available_actions

Lists the actions that can be applied to this module

=cut

sub available_actions {
    return [
        'default_actions',
        'set_role',
        'set_unregdate',
        'set_access_duration',
        'no_action',
        'set_time_balance',
        'set_bandwidth_balance',
        'destination_url',
    ];
}

=head2 display

Defines whether or not a module should be displayed

=cut

sub display {$TRUE}

=head2 _build_username

Builder for the username (to restore from the session)

=cut

sub _build_username {
    my ($self) = @_;
    return $self->app->session->{username} // $default_pid;
}

=head2 after username

Set the username in the session and in the new_node_info after setting it

=cut

after 'username' => sub {
    my ($self) = @_;

    if(defined($self->{username})){
        get_logger->info("User ".$self->{username}." has authenticated on the portal.");
        $self->new_node_info->{pid} = $self->{username};
        $self->app->session->{username} = $self->{username};
        if(!person_exist($self->{username})){
            person_add($self->{username});
        }
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
    return lc($name);
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
    my $app = $self->app;
    return {
        timer => $Config{'captive_portal'}{'network_redirect_delay'},
        destination_url  => $app->session->{destination_url} || $app->profile->getRedirectURL,
        initial_delay => $Config{'captive_portal'}{'network_detection_initial_delay'},
        retry_delay   => $Config{'captive_portal'}{'network_detection_retry_delay'},
        external_ip => $Config{'captive_portal'}{'network_detection_ip'},
        auto_redirect => $Config{'captive_portal'}{'network_detection'},
        image_path => $Config{'captive_portal'}{'image_path'},
        title => "release: enabling network",
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
    $self->app->current_module_id($self->id);
    if($self->parent && $self->parent->can("current_module")){
        $self->parent->current_module($self->id);
    }

    unless($self->path_is_allowed('/'.$self->app->request->path)){
        get_logger->debug('/'.$self->app->request->path." is not allowed in module : ".$self->id);
        $self->redirect_root();
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
    my ($self) = @_;
    # Execute the default actions before anything else
    if(my $params = $self->actions->{default_actions}) {
        $AUTHENTICATION_ACTIONS{default_actions}->($self, @{$params});
    }

    while(my ($action, $params) = each %{$self->actions}){
        next if $action eq "default_actions";
        get_logger->debug("Executing action $action with params : ".join(',', @{$params}));
        $AUTHENTICATION_ACTIONS{$action}->($self, @{$params});
    }
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
        $self->app->flash->{error} = "Could not execute actions" unless($self->app->flash->{error});
        $self->redirect_root();
        return;
    }
    $self->parent->next();

    if(my $redirect = $self->app->request->param("done_redirect_to")) {
        $self->app->redirect($redirect);
    }
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

=head2 redirect_root

Allows to redirect to the root page of the captive portal to recalculate where the user should be

=cut

sub redirect_root {
    my ($self) = @_;
    $self->app->redirect("/captive-portal");
}

=head2 detach

Stop the execution of the request

=cut

sub detach {
    die captiveportal::DynamicRouting::Detach->new;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

