package captiveportal::PacketFence::Controller::CaptivePortal;
use Moose;
use namespace::autoclean;
use pf::web::constants;
use URI::Escape::XS qw(uri_escape uri_unescape);
use HTML::Entities;
use pf::enforcement qw(reevaluate_access);
use pf::config;
use pf::log;
use pf::fingerbank;
use pf::util;
use pf::Portal::Session;
use pf::web;
use pf::node;
use pf::useragent;
use pf::violation;
use pf::class;
use Cache::FileCache;
use pf::activation;
use List::MoreUtils qw(any);
use List::Util qw(first);
use pf::factory::provisioner;

BEGIN { extends 'captiveportal::Base::Controller'; }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config( namespace => 'captive-portal' );

our $USERAGENT_CACHE =
  new Cache::FileCache( { 'namespace' => 'CaptivePortal_UserAgents' } );

our $LOST_DEVICES_CACHE =
  new Cache::FileCache( { 'namespace' => 'CaptivePortal_LostDevices' } );

=head1 NAME

captiveportal::PacketFence::Controller::CaptivePortal -  CaptivePortal Controller for captiveportal

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('validateMac');
    $c->forward('nodeRecordUserAgent');
    $c->forward('processFingerbank');
    $c->forward('checkForViolation');
    $c->forward('checkIfNeedsToRegister');
    $c->forward('checkIfPending');
    $c->forward('unknownState');
}

=head2 validateMac

Validate the mac address of the current portal user

=cut

sub validateMac : Private {
    my ( $self, $c ) = @_;
    my $portalSession = $c->portalSession;
    my $mac           = $portalSession->clientMac;

    if ( !$c->session->{"preregistration"} && !valid_mac($mac) ) {
        $self->showError( $c, "error: not found in the database" );
        $c->detach;
    }
}

=head2 nodeRecordUserAgent

Records the user agent information

=cut

sub nodeRecordUserAgent : Private {
    my ( $self, $c ) = @_;
    my $user_agent    = $c->request->user_agent;
    my $logger        = get_logger;
    my $portalSession = $c->portalSession;
    my $mac           = $portalSession->clientMac;
    unless ($user_agent) {
        $logger->warn("[$mac] has no user agent");
        return;
    }

    # caching useragents, if it's the same don't bother triggering violations
    my $cached_useragent = $USERAGENT_CACHE->get($mac);

    # Cache hit
    return
      if ( defined($cached_useragent) && $user_agent eq $cached_useragent );

    # Caching and updating node's info
    $logger->debug("[$mac] adding user-agent to cache");
    $USERAGENT_CACHE->set( $mac, $user_agent, "5 minutes" );

    # Recording useragent
    $logger->info(
        "[$mac] Updating node user_agent with useragent: '$user_agent'");
    node_modify( $mac, ( 'user_agent' => $user_agent ) );

    # updates the node_useragent information and fires relevant violations triggers
    return pf::useragent::process_useragent( $mac, $user_agent );
}

=head2 processFingerbank

=cut

sub processFingerbank :Private {
    my ( $self, $c ) = @_;

    my $portalSession   = $c->portalSession;
    my $mac             = $portalSession->clientMac;
    my $user_agent      = $c->request->user_agent;
    my $node_attributes = node_attributes($mac);

    my %fingerbank_query_args = (
        user_agent          => $user_agent,
        mac                 => $mac,
        dhcp_fingerprint    => $node_attributes->{'dhcp_fingerprint'},
        dhcp_vendor         => $node_attributes->{'dhcp_vendor'},
    );

    pf::fingerbank::process(\%fingerbank_query_args);
}

=head2 checkForViolation

TODO: documention

=cut

sub checkForViolation : Private {
    my ( $self, $c ) = @_;
    my $portalSession = $c->portalSession;
    my $mac           = $portalSession->clientMac;
    my $logger        = $c->log;
    my $violation = violation_view_top($mac);
    if ($violation) {

        $c->stash->{'user_agent'} = $c->request->user_agent;
        my $request = $c->req;

        # There is a violation, redirect the user
        # FIXME: there is not enough validation below
        my $vid      = $violation->{'vid'};
        my $SCAN_VID = 1200001;

        # detect if a system scan is in progress, if so redirect to scan in progress page
        if (   $vid == $SCAN_VID
            && $violation->{'ticket_ref'}
            =~ /^Scan in progress, started at: (.*)$/ ) {
            $logger->info(
                "[$mac] captive portal redirect to the scan in progress page");
            $c->detach( 'Remediation', 'scan_status', [$1] );
        }
        my $class    = class_view($vid);
        my $template = $class->{'template'};
        $logger->info(
            "[$mac] captive portal redirect on violation vid: $vid, redirect template: $template"
        );

        # The little redirect dance here is controlled by frames which are inherently alterable by the user
        # TODO: We need to validate that a user cannot request a frame with the enable button activated

        # enable button
        if ( $request->param("enable_menu") ) {
            $logger->debug(
                "[$mac] violation redirect: generating enable button frame (enable_menu = 1)"
            );
            $c->detach( 'Enabler', 'index' );
        } elsif ( $class->{'auto_enable'} eq 'Y' ) {
            $logger->debug(
                "[$mac] violation redirect: showing violation remediation page inside a frame"
            );
            $c->detach( 'Redirect', 'index' );
        }
        $logger->debug(
            "[$mac] violation redirect: showing violation remediation page directly since there is no enable button"
        );

        # Retrieve violation template name

        my $subTemplate = $self->getSubTemplate( $c, $class->{'template'} );
        $logger->info("[$mac] Showing the $subTemplate  remediation page.");
        my $node_info = node_view($mac);
        $c->stash(
            'template'     => 'remediation.html',
            'sub_template' => $subTemplate,
            map { $_ => $node_info->{$_} }
              qw(dhcp_fingerprint last_switch last_port
              last_vlan last_connection_type last_ssid username)
        );
        $c->detach;
    }
}


=head2 checkIfNeedsToRegister

TODO: documention

=cut

sub checkIfNeedsToRegister : Private {
    my ($self, $c) = @_;
    my $request = $c->request;
    my $unreg;
    my $portalSession = $c->portalSession;
    my $profile = $portalSession->profile;
    my $mac           = $portalSession->clientMac;
    my $logger        = $c->log;
    if ($request->param('unreg')) {
        $c->log->info("Unregister node $mac");
        $unreg = node_deregister($mac);    # set node status to 'unreg'
    } else {
        $unreg = node_is_unregistered($mac);    # check if node status is 'unreg'
    }
    $c->stash(unreg => $unreg,);
    if ($unreg && isenabled($Config{'trapping'}{'registration'})) {

        # Redirect to the billing engine if enabled
        if (isenabled($portalSession->profile->getBillingEngine)) {
            $logger->info("[$mac] redirected to billing page on ".$profile->name." portal");
            $c->detach('Pay' => 'index');
        } elsif ( $profile->nbregpages > 0 ) {
            $logger->info(
                "[$mac] redirected to multi-page registration process on ".$profile->name." portal");
            $c->detach('Authenticate', 'next_page');
        } elsif ($portalSession->profile->guestRegistrationOnly) {

            # Redirect to the guests self registration page if configured to do so
            $logger->info("[$mac] redirected to guests self registration page on ".$profile->name." portal");
            $c->detach('Signup' => 'index');
        } else {
            $logger->info("[$mac] redirected to authentication page on ".$profile->name." portal");
            $c->detach('Authenticate', 'index');
        }
    }
    return;
}

=head2 checkIfPending

Check if node is the pending state

=cut

sub checkIfPending : Private {
    my ( $self, $c ) = @_;
    my $portalSession = $c->portalSession;
    my $profile       = $c->profile;
    my $mac           = $portalSession->clientMac;
    my $node_info     = node_view($mac);
    my $request       = $c->request;
    my $logger        = $c->log;
    if ( $node_info && $node_info->{'status'} eq $pf::node::STATUS_PENDING ) {
        if (defined(my $provisioner = $profile->findProvisioner($mac))) {
            unless ($provisioner->authorize($mac)) {
                $c->stash(
                    template => $provisioner->template,
                    provisioner => $provisioner,
                );
                $c->detach();
            } elsif (!pf::activation::activation_has_entry($mac,'sms') ) {
                node_modify($mac,status => $pf::node::STATUS_REGISTERED);
                reevaluate_access( $mac, 'manage_register' ) unless $provisioner->skipDeAuth;
                $c->detach( Release => 'index' );
            }
        }
        if ( pf::activation::activation_has_entry($mac,'sms') ) {
            $c->stash(
                template => 'guest/sms_confirmation.html',
                post_uri => '/activate/sms'
            );
        } elsif ( $request->secure ) {

            # we drop HTTPS for pending so we can perform our Internet detection and avoid all sort of certificate errors
            print $c->response->redirect( "http://"
                  . $Config{'general'}{'hostname'} . "."
                  . $Config{'general'}{'domain'}
                  . '/captive-portal?destination_url='
                  . uri_escape( $portalSession->destinationUrl ) );
        } else {
            $c->stash(
                template => 'pending.html',
                retry_delay =>
                  $CAPTIVE_PORTAL{'NET_DETECT_PENDING_RETRY_DELAY'},
                external_ip =>
                  $Config{'captive_portal'}{'network_detection_ip'},
                redirect_url => $Config{'trapping'}{'redirecturl'},
                initial_delay =>
                  $CAPTIVE_PORTAL{'NET_DETECT_PENDING_INITIAL_DELAY'},
                image_path => $Config{'captive_portal'}{'image_path'},
            );

            # override destination_url if we enabled the always_use_redirecturl option
            if ( isenabled( $Config{'trapping'}{'always_use_redirecturl'} ) )
            {
                $c->stash->{'destination_url'} =
                  $Config{'trapping'}{'redirecturl'};
            }

        }
        $c->detach;
    }
}

=head2 unknownState

NODES IN AN UKNOWN STATE
aka you shouldn't be here but if you are we need to handle you.

Here we are using a cache to prevent malicious or accidental DoS of the captive portal
through too many access reevaluation requests (since this is rather expensive especially in VLAN mode)

=cut

sub unknownState : Private {
    my ( $self, $c ) = @_;
    my $mac   = $c->portalSession->clientMac;
    my $logger = $c->log;
    my $cached_lost_device = $LOST_DEVICES_CACHE->get($mac);

    my $server_addr = $c->request->{env}->{SERVER_ADDR};
    my $management_ip = $pf::config::management_network->{'Tvip'} || $pf::config::management_network->{'Tip'};
    if( $server_addr eq $management_ip){
        $logger->error("Hitting unknownState on the management address ($server_addr)");
        $self->showError($c, "You hit the captive portal on the management interface. The management console is on port 1443.");
    }

    # After 5 requests we won't perform re-eval for 5 minutes
    if ( !defined($cached_lost_device) || $cached_lost_device <= 5 ) {

        # set the cache, incrementing before on purpose (otherwise it's not hitting the cache)
        $LOST_DEVICES_CACHE->set( $mac, ++$cached_lost_device, "5 minutes");

        $c->log->info(
          "[$mac] shouldn't reach here. Calling access re-evaluation. " .
          "Make sure your network device configuration is correct."
        );
        my $node = node_view($mac);
        my $switch;
        my $last_switch_id = $node->{last_switch};
        if( defined $last_switch_id ) {
            $switch = pf::SwitchFactory->instantiate($last_switch_id);
        }

        if(defined($switch) && $switch && $switch->supportsWebFormRegistration){
            $logger->info("(" . $switch->{_id} . ") supports web form release. Will use this method to authenticate [$mac]");
            $c->stash(
                template => 'webFormRelease.html',
                content => $switch->getAcceptForm($mac,
                                $c->stash->{destination_url},
                                new pf::Portal::Session()->session,
                                ),
            );
            $c->detach;
        }
        else{
            reevaluate_access( $mac, 'redir.cgi' );
        }

    }
    $self->showError( $c, "Your network should be enabled within a minute or two. If it is not reboot your computer.");
}


sub endPortalSession : Private {
    my ( $self, $c ) = @_;
    my $logger        = get_logger;
    my $portalSession = $c->portalSession;
    my $profile       = $c->profile;

    # First blast at handling portalSession object
    my $mac             = $portalSession->clientMac();
    my $destination_url = $c->stash->{destination_url};

    # violation handling
    my $count = violation_count($mac);
    if ( $count != 0 ) {
        print $c->response->redirect( '/captive-portal?destination_url='
              . uri_escape($destination_url) );
        $logger->info("[$mac] more violations yet to come");
    }

    # show provisioner template if we're authorizing and skiping deauth
    my $provisioner = $profile->findProvisioner($mac);
    if(defined($provisioner) && $provisioner->authorize($mac) && $provisioner->skipDeAuth) {
        # handle autoconfig provisioning
        $c->stash( template => $provisioner->template );
        $c->detach();
    }

    # we drop HTTPS so we can perform our Internet detection and avoid all sort of certificate errors
    if ( $c->request->secure ) {
        $c->response->redirect( "http://"
              . $Config{'general'}{'hostname'} . "."
              . $Config{'general'}{'domain'}
              . '/access?destination_url='
              . uri_escape($destination_url) );
    }

    $c->forward( 'Release' => 'index' );
}

sub getSubTemplate {
    my ( $self, $c, $template ) = @_;
    my $portalSession = $c->portalSession;
    return "violations/$template.html";
#    my $langs         = $portalSession->getRequestLanguages();
    my $langs         = [];
    my $paths         = $portalSession->templateIncludePath();
    my @subTemplates =
      map { "violations/$template" . ( $_ ? ".$_" : "" ) . ".html" } @$langs,
      '';
    return first { -f $_ } map {
        my $path = $_;
        map {"$path/$_"} @subTemplates
    } @$paths;
}

=head2 webNodeRegister

This sub is meant to be redefined by pf::web::custom to fit your specific needs.
See F<pf::web::custom> for examples.

=cut

sub webNodeRegister : Private {
    my ($self, $c, $pid, %info ) = @_;
    my $logger        = Log::Log4perl::get_logger(__PACKAGE__);
    my $portalSession = $c->portalSession;

    # FIXME quick and hackish fix for #1505. A proper, more intrusive, API changing, fix should hit devel.
    my $mac;
    if ( defined( $portalSession->guestNodeMac ) ) {
        $mac = $portalSession->guestNodeMac;
    } else {
        $mac = $portalSession->clientMac;
    }

    if ( is_max_reg_nodes_reached( $mac, $pid, $info{'category'} ) ) {
        $c->detach('maxRegNodesReached');
    }
    node_register( $mac, $pid, %info );

    my $provisioner = $c->profile->findProvisioner($mac);
    unless ( (defined($provisioner) && $provisioner->skipDeAuth) || $c->user_cache->get("do_not_deauth") ) {
        my $node = node_view($mac);
        my $switch;
        my $last_switch_id = $node->{last_switch};
        if( defined $last_switch_id ) {
            $switch = pf::SwitchFactory->instantiate($last_switch_id);
        }

        if(defined($switch) && $switch && $switch->supportsWebFormRegistration){
            $logger->info("Switch supports web form release.");
            $c->stash(
                template => 'webFormRelease.html',
                content => $switch->getAcceptForm($mac,
                                $c->stash->{destination_url},
                                new pf::Portal::Session()->session,
                                ),
            );
            $c->detach;
        }
        else{
            reevaluate_access( $mac, 'manage_register' );
        }
    }

    # we are good, push the registration
}



=head2 maxRegNodesReached

TODO: documention

=cut

sub maxRegNodesReached : Private {
    my ( $self, $c ) = @_;
    $self->showError($c, "You have reached the maximum number of devices you are able to register with this username.");
}



=head2 default

Standard 404 error page

=cut

sub default : Path {
    my ( $self, $c ) = @_;
    $c->response->body('Page not found');
    $c->response->status(404);
}

sub error : Private { }

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
