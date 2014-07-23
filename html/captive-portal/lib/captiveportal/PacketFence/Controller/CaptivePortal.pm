package captiveportal::PacketFence::Controller::CaptivePortal;
use Moose;
use namespace::autoclean;
use pf::web::constants;
use URI::Escape::XS qw(uri_escape uri_unescape);
use HTML::Entities;
use pf::enforcement qw(reevaluate_access);
use pf::config;
use pf::log;
use pf::util;
use pf::Portal::Session;
use pf::web;
use pf::node;
use pf::useragent;
use pf::violation;
use pf::class;
use Cache::FileCache;
use pf::activation;
use pf::os;
use List::MoreUtils qw(any);

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
    $c->forward('checkForProvisioningSupport');
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
    $c->log->info("mac : $mac");
    if ( !valid_mac($mac) ) {
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
        $logger->warn("$mac has no user agent");
        return;
    }

    # caching useragents, if it's the same don't bother triggering violations
    my $cached_useragent = $USERAGENT_CACHE->get($mac);

    # Cache hit
    return
      if ( defined($cached_useragent) && $user_agent eq $cached_useragent );

    # Caching and updating node's info
    $logger->trace("adding $mac user-agent to cache");
    $USERAGENT_CACHE->set( $mac, $user_agent, "5 minutes" );

    # Recording useragent
    $logger->info(
        "Updating node $mac user_agent with useragent: '$user_agent'");
    node_modify( $mac, ( 'user_agent' => $user_agent ) );

    # updates the node_useragent information and fires relevant violations triggers
    return pf::useragent::process_useragent( $mac, $user_agent );
}

=head2 checkForProvisioningSupport

checks if provisioning is supported support

=cut

sub checkForProvisioningSupport : Private {
    my ( $self, $c ) = @_;
    if (isenabled($Config{'provisioning'}{'autoconfig'})) {
        return ( $c->forward('supportsMobileConfigProvisioning') ||
                 $c->forward('supportsAndroidConfigProvisioning') );
    }
    return 0;
}

=head2 supportsMobileConfigProvisioning

TODO: documention

=cut

sub supportsMobileConfigProvisioning : Private {
    my ( $self, $c ) = @_;
    if($self->matchAnyOses($c,'Apple iPod, iPhone or iPad')) {
        $c->user_cache->set("mac:" . $c->portalSession->clientMac . ":do_not_deauth" ,1);
        return 1;
    }
    return 0;
}

=head2 supportsAndroidConfigProvisioning

TODO: documention

=cut

sub supportsAndroidConfigProvisioning : Private {
    my ( $self, $c ) = @_;
    if($self->matchAnyOses($c,'Android')) {
        $c->user_cache->set("mac:" . $c->portalSession->clientMac . ":do_not_deauth" ,1);
        return 1;
    }
    return 0;
}

sub matchAnyOses {
    my ($self, $c, @toMatch) = @_;
    my $node_attributes = node_attributes( $c->portalSession->clientMac );
    my @fingerprint =
      dhcp_fingerprint_view( $node_attributes->{'dhcp_fingerprint'} );
    my $os = $fingerprint[0]->{'os'};
    return $FALSE unless defined $os;
    return $FALSE unless any { $os =~ $_ } @toMatch;
    my $config_category = $Config{'provisioning'}{'category'};
    my $node_cat = $node_attributes->{'category'};

    # validating that the node is under the proper category for mobile config provioning
    return $TRUE if ( $config_category eq 'any' || (defined($node_cat) && $node_cat eq $config_category));
    return $FALSE;
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
        my $SCAN_VID = 12003;

        # detect if a system scan is in progress, if so redirect to scan in progress page
        if (   $vid == $SCAN_VID
            && $violation->{'ticket_ref'}
            =~ /^Scan in progress, started at: (.*)$/ ) {
            $logger->info(
                "captive portal redirect to the scan in progress page");
            $c->detach( 'scan_status', [$1] );
        }
        my $class    = class_view($vid);
        my $template = $class->{'template'};
        $logger->info(
            "captive portal redirect on violation vid: $vid, redirect template: $template"
        );

        # The little redirect dance here is controlled by frames which are inherently alterable by the user
        # TODO: We need to validate that a user cannot request a frame with the enable button activated

        # enable button
        if ( $request->param("enable_menu") ) {
            $logger->debug(
                "violation redirect: generating enable button frame (enable_menu = 1)"
            );
            $c->detach( 'Enabler', 'index' );
        } elsif ( $class->{'auto_enable'} eq 'Y' ) {
            $logger->debug(
                "violation redirect: showing violation remediation page inside a frame"
            );
            $c->detach( 'Redirect', 'index' );
        }
        $logger->debug(
            "violation redirect: showing violation remediation page directly since there is no enable button"
        );

        # Retrieve violation template name

        my $subTemplate = $self->getSubTemplate( $c, $class->{'template'} );
        $logger->info("Showing the $subTemplate  remediation page.");
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

        $logger->info("$mac redirected to ".$profile->name);
        # Redirect to the billing engine if enabled
        if (isenabled($portalSession->profile->getBillingEngine)) {
            $logger->info("$mac redirected to billing page");
            $c->detach('Pay' => 'index');
        } elsif ( $profile->nbregpages > 0 ) {
            $logger->info(
                "$mac redirected to multi-page registration process");
            $c->detach('Authenticate', 'next_page');
        } elsif ($portalSession->profile->guestRegistrationOnly) {

            # Redirect to the guests self registration page if configured to do so
            $logger->info("$mac redirected to guests self registration page");
            $c->detach('Signup' => 'index');
        } else {
            $logger->info("$mac redirected to authentication page");
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
    if ( $node_info && $node_info->{'status'} eq $pf::node::STATUS_PENDING ) {
        if ( pf::activation::activation_has_entry($mac,'sms') ) {
            node_deregister($mac);
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
                  . uri_escape( $portalSession->_build_destinationUrl ) );
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

    # After 5 requests we won't perform re-eval for 5 minutes
    if ( !defined($cached_lost_device) || $cached_lost_device <= 5 ) {

        # set the cache, incrementing before on purpose (otherwise it's not hitting the cache)
        $LOST_DEVICES_CACHE->set( $mac, ++$cached_lost_device, "5 minutes");

        $c->log->info(
          "MAC $mac shouldn't reach here. Calling access re-evaluation. " .
          "Make sure your network device configuration is correct."
        );
        my $node = node_view($mac);
        my $switch = pf::SwitchFactory->getInstance()->instantiate($node->{last_switch});
        use Data::Dumper;
        $logger->info(Dumper($switch));
        if($switch->supportsWebFormRegistration){
            $logger->info("Switch supports web form release. Will use this method to authenticate the user");
            $c->stash(
                template => 'webFormRelease.html',
                content => $switch->getAcceptForm($mac, $c->stash->{destination_url}),
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

    # First blast at handling portalSession object
    my $mac             = $portalSession->clientMac();
    my $destination_url = $c->stash->{destination_url};

    # violation handling
    my $count = violation_count($mac);
    if ( $count != 0 ) {
        print $c->response->redirect( '/captive-portal?destination_url='
              . uri_escape($destination_url) );
        $logger->info("more violations yet to come for $mac");
    }

    # handle mobile provisioning if relevant
    $c->forward('provisioning') if ( $c->forward('checkForProvisioningSupport') );

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

=head2 provisioning

=cut

sub provisioning : Private {
    my ( $self, $c ) = @_;
    if($c->forward('supportsMobileConfigProvisioning') ) {
        $c->detach('release_with_xmlconfig');
    } elsif( $c->forward('supportsAndroidConfigProvisioning') ) {
        $c->detach('release_with_android');
    }
}

sub release_with_xmlconfig : Private {
    my ( $self, $c ) = @_;
    $c->stash( template => 'release_with_xmlconfig.html');
}

sub release_with_android : Private {
    my ( $self, $c ) = @_;
    $c->stash( template => 'release_with_android.html');
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

    unless ( $c->user_cache->get("mac:$mac:do_not_deauth") ) {
        my $node = node_view($mac);
        my $switch = pf::SwitchFactory->getInstance()->instantiate($node->{last_switch});
        if($switch->supportsWebFormRegistration){
            $logger->info("Switch supports web form release.");
            $c->stash(
                template => 'webFormRelease.html',
                content => $switch->getAcceptForm($mac, $c->stash->{destination_url}),
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

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
