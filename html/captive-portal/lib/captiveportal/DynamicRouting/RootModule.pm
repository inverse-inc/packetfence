package captiveportal::DynamicRouting::RootModule;

=head1 NAME

DynamicRouting::RootModule

=head1 DESCRIPTION

Root module for Dynamic Routing

=cut

use Moose;
extends 'captiveportal::DynamicRouting::AndModule';
with 'captiveportal::DynamicRouting::Routed';

has '+route_map' => (default => sub {
    tie my %map, 'Tie::IxHash', (
        '/status/billing' => \&direct_route_billing, 
        '/billing.*' => \&check_billing_bypass,
        '/logout' => \&logout,
    );
    return \%map;

});

use pf::log;
use pf::node;
use pf::config;
use pf::violation;
use pf::constants::scan qw($POST_SCAN_VID);
use captiveportal::DynamicRouting::AuthModule::Billing;

has '+parent' => (required => 0);

sub logout {
    my ($self) = @_;
    $self->app->reset_session;
    $self->app->redirect("/captive-portal"); 
}

sub done {
    my ($self) = @_;
    $self->execute_actions();
    $self->release();
}

sub release {
    my ($self) = @_;
    return $self->app->redirect("/access") unless($self->app->request->path eq "access");

    $self->app->reset_session;
    $self->render("release.html", $self->_release_args());
}

sub handle_violations {
    my ($self) = @_;
    my $mac           = $self->current_mac;

    my $violation = violation_view_top($mac);

    return 1 unless(defined($violation));
        
    return 1 if ($violation->{vid} == $POST_SCAN_VID);

    $self->app->redirect("/violation");
    return 0;
}

sub execute_child {
    my ($self) = @_;

    # Make sure there are no outstanding violations
    return unless($self->handle_violations());

    # The user should be released, he is already registered and doesn't have any violation
    # HACK alert : E-mail registration has the user registered but still going in the portal
    # release_bypass is there for that. If it is set, it will keep the user in the portal
    my $node = node_view($self->current_mac);
    if($node->{status} eq "reg" && !$self->app->session->{release_bypass}){
        return $self->release();
    }
    $self->SUPER::execute_child();
}

sub execute_actions {
    my ($self) = @_;
    $self->new_node_info->{status} = "reg";
    $self->apply_new_node_info();
    return $TRUE;
}

sub apply_new_node_info {
    my ($self) = @_;
    get_logger->debug(sub { use Data::Dumper; "Applying new node_info to user ".Dumper($self->new_node_info)});
    $self->app->flash->{notice} = "Role ".$self->new_node_info->{category}." has been assigned to your device with unregistration date : ".$self->new_node_info->{unregdate};
    node_modify($self->current_mac, %{$self->new_node_info()});
}

sub direct_route_billing {
    my ($self) = @_;
    my $node = node_view($self->current_mac);
    if($node->{status} eq "reg"){
        $self->session->{direct_route_billing} = $TRUE;
        $self->module_map({'_DYNAMIC_BILLING_MODULE_' => captiveportal::DynamicRouting::AuthModule::Billing->new(
                    id => '_DYNAMIC_BILLING_MODULE_', 
                    app => $self->app, 
                    parent => $self, 
                    source_id => join(',',map {$_->id} $self->app->profile->getBillingSources()),
                )});
        $self->modules_order(['_DYNAMIC_BILLING_MODULE_']);
        $self->SUPER::execute_child();
    }
    else {
        $self->app->error("This section cannot be accessed by unregistered users");
    }
    
}

sub check_billing_bypass {
    my ($self) = @_;
    if($self->session->{direct_route_billing}){
        $self->direct_route_billing();
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

