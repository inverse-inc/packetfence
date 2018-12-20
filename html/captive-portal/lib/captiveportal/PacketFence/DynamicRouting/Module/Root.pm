package captiveportal::PacketFence::DynamicRouting::Module::Root;

=head1 NAME

DynamicRouting::RootModule

=head1 DESCRIPTION

Root module for Dynamic Routing

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Chained';
with 'captiveportal::Role::Routed';

has '+route_map' => (default => sub {
    tie my %map, 'Tie::IxHash', (
        '/status/billing' => \&direct_route_billing,
        '/billing.*' => \&check_billing_bypass,
        '/logout' => \&logout,
        '/access' => \&release,
        '/record_destination_url' => \&record_destination_url,
    );
    return \%map;

});

use pf::log;
use pf::node;
use pf::config qw($default_pid);
use pf::constants qw($TRUE $FALSE);
use pf::util;
use pf::violation;
use pf::constants::scan qw($POST_SCAN_VID);
use pf::inline;
use pf::Portal::Session;
use pf::SwitchFactory;
use pf::enforcement qw(reevaluate_access);
use captiveportal::DynamicRouting::Module::Authentication::Billing;

has '+parent' => (required => 0);

=head2 around done

Once this is done, we release the user on the network

=cut

around 'done' => sub {
    my ($orig, $self) = @_;
    if($self->app->preregistration){
        $self->show_preregistration_account();
    }
    else {
        if($self->execute_actions()){
            $self->release();
        }
        else {
            $self->app->reset_session();
            $self->redirect_root();
        }
    }
};

=head2 logout

Logout of the captive portal

=cut

sub logout {
    my ($self) = @_;
    $self->app->reset_session;
    $self->redirect_root();
}

=head2 release

Reevaluate the access of the user and show the release page

=cut

sub release {
    my ($self) = @_;
    # One last check for the violations
    return unless($self->handle_violations());

    return $self->app->redirect("http://" . $self->app->request->header("host") . "/access?lang=".$self->app->session->{lang}) unless($self->app->request->path eq "access");

    get_logger->info("Releasing device");

    $self->app->reset_session;

    unless($self->handle_web_form_release){
        reevaluate_access( $self->current_mac, 'manage_register', force => 1 );
        $self->render("release.html", $self->_release_args());
    }
}

=head2 handle_web_form_release

Handle release done through a form posted for web authentication

=cut

sub handle_web_form_release {
    my ($self) = @_;
    my $inline = pf::inline->new();
    my $node = $self->node_info;
    my $switch;
    if (!($inline->isInlineIP($self->current_ip))) {
        my $last_switch_id = $node->{last_switch};
        if( defined $last_switch_id ) {
            $switch = pf::SwitchFactory->instantiate($last_switch_id);
        }
    }
    my $session = new pf::Portal::Session(client_mac => $self->current_mac)->session;
    if(defined($switch) && $switch && $switch->supportsWebFormRegistration && defined($session->param('is_external_portal')) && $session->param('is_external_portal')){
        get_logger->info("(" . $switch->{_id} . ") supports web form release. Will use this method to authenticate");
        $self->render('webFormRelease.html', {
            content => $switch->getAcceptForm($self->current_mac, $self->app->session->{destination_url}, $session),
            %{$self->_release_args()}
        });
        return $TRUE;
    }
    return $FALSE;
}

=head2 unknown_state

When the user shouldn't on the portal, but he is

=cut

sub unknown_state {
    my ($self) = @_;
    if($self->app->preregistration){
        $self->show_preregistration_account();
    }
    else {
        unless($self->handle_web_form_release){

            my $cached_lost_device = $self->app->user_cache->get("unknown_state_hits");
            if ( !defined($cached_lost_device) || $cached_lost_device <= 5 ) {
                # set the cache, incrementing before on purpose (otherwise it's not hitting the cache)
                $self->app->user_cache->set("unknown_state_hits", ++$cached_lost_device, "5 minutes");

                get_logger->info("Reevaluating access of device.");

                reevaluate_access( $self->current_mac, 'manage_register', force => 1 );
            }

            return $self->app->error("Your network should be enabled within a minute or two. If it is not reboot your computer.");
        }
    }
}

=head2 handle_violations

Check if the user has a violation and redirect him to the proper page if he does

=cut

sub handle_violations {
    my ($self) = @_;
    my $mac           = $self->current_mac;

    my $violation = violation_view_top($mac);

    return 1 unless(defined($violation));

    return 1 if ($violation->{vid} == $POST_SCAN_VID);

    $self->app->redirect("/violation");
    return 0;
}

=head2 validate_mac

Validate that we have a valid MAC address

=cut

sub validate_mac {
    my ($self) = @_;
    if(!valid_mac($self->current_mac) && !$self->app->preregistration){
        $self->app->error("error: not found in the database");
        return $FALSE;
    }
    return $TRUE;
}

=head2 execute_actions

Execute the flow for this module

=cut

sub execute_child {
    my ($self) = @_;

    return unless($self->validate_mac);

    # Make sure there are no outstanding violations
    return unless($self->handle_violations());

    # The user should be released, he is already registered and doesn't have any violation
    # HACK alert : E-mail registration has the user registered but still going in the portal
    # release_bypass is there for that. If it is set, it will keep the user in the portal
    my $node = node_view($self->current_mac);
    if($self->app->profile->canAccessRegistrationWhenRegistered() && $self->app->session->{release_bypass}) {
        get_logger->info("Allowing user through portal even though he is registered as the release bypass is set and the connection profile is configured to let registered users use the registration module of the portal.");
    }
    elsif(defined($node->{status}) && $node->{status} eq "reg"){
        return $self->unknown_state();
    }
    $self->SUPER::execute_child();
}

=head2 execute_actions

Register the device and apply the new node info

=cut

sub execute_actions {
    my ($self) = @_;
    return $self->apply_new_node_info();
}

=head2 apply_new_node_info

Apply the new node info in the session to the node

=cut

sub apply_new_node_info {
    my ($self) = @_;
    get_logger->debug(sub { use Data::Dumper; "Applying new node_info to user ".Dumper($self->new_node_info)});

    my $node_view = node_view($self->current_mac);

    # When device is pending, we take the role+unregdate from the computed node info. 
    # This way, if the role wasn't set during the portal process (like in provisioning agent re-install), then it will pick the role it had before
    if($self->node_info->{status} eq $pf::node::STATUS_PENDING) {
        unless($self->username){
            if($self->new_node_info->{pid}){
                $self->username($self->new_node_info->{pid});
            }
            else {
                $self->username($default_pid);
            }
        }
        $self->new_node_info->{category} = $self->node_info->{category};
        $self->new_node_info->{unregdate} = $self->node_info->{unregdate};
    }
    # We take the role+unregdate from the computed node info. This way, if the role wasn't set during the portal process (like in provisioning agent re-install), then it will pick the role it had before
    $self->new_node_info->{category} = $self->node_info->{category};
    $self->new_node_info->{unregdate} = $self->node_info->{unregdate};

    # We check if the username is the default PID. If it is and there is a non-default PID already on the node, we take it instead of the default PID
    if($self->username eq $default_pid) {
        get_logger->debug("Username is set to the default PID and there is already a PID set on the node (".$node_view->{pid}."). Keeping it instead of the default PID.");
        $self->username($node_view->{pid});
    }

    my ( $status, $status_msg );
    ( $status, $status_msg ) = pf::node::node_register($self->current_mac, $self->username, %{$self->new_node_info()});
    if ($status) {
        $self->app->flash->{notice} = "";
        my $notice = "";
        if($self->new_node_info->{category}) {
            $notice .= $self->app->i18n_format("Role %s has been assigned to your device", $self->new_node_info->{category});
        }
        if($self->new_node_info->{unregdate}) {
            $notice .= $self->app->i18n_format(" with unregistration date : %s,", $self->new_node_info->{unregdate});
        }
        if ($self->new_node_info->{time_balance}) {
            $notice .= $self->app->i18n_format(" with time balance : %s,", $self->new_node_info->{time_balance});
        }
        if ($self->new_node_info->{bandwidth_balance}) {
            $notice .= $self->app->i18n_format(" with bandwidth balance : %s,", $self->new_node_info->{bandwidth_balance});
        }
        $self->app->flash->{notice} = [ $notice ];
        return $TRUE;
    }
    else {
        $self->app->error("Couldn't register your device. Please contact your local support staff.");
        $self->detach();
    }
}

=head2 direct_route_billing

Bypass to allow direct access to billing module from the status page or post-registration

=cut

sub direct_route_billing {
    my ($self) = @_;
    my $node = node_view($self->current_mac);
    if($node->{status} eq "reg"){
        $self->session->{direct_route_billing} = $TRUE;
        $self->module_map({'_DYNAMIC_BILLING_MODULE_' => captiveportal::DynamicRouting::Module::Authentication::Billing->new(
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

=head2 check_billing_bypass

Do we need to bypass to billing

=cut

sub check_billing_bypass {
    my ($self) = @_;
    if($self->session->{direct_route_billing}){
        $self->direct_route_billing();
    }
    $self->SUPER::execute_child();
}

=head2 show_preregistration_account

Show the account details created in the pre-registration

=cut

sub show_preregistration_account {
    my ($self) = @_;
    captiveportal::DynamicRouting::Module::ShowLocalAccount->new(
        id => "__TMP_ShowLocalAccount_Module__", 
        parent => $self, 
        app => $self->app, 
        skipable => $FALSE
    )->execute();
}

=head2 record_destination_url

Record the destination URL wanted by the user

=cut

sub record_destination_url {
    my ($self) = @_;
    $self->app->session->{user_destination_url} = $self->app->request->param('destination_url');
    $self->app->response_code(200);
    $self->app->template_output('');
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

