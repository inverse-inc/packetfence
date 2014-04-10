package captiveportal::PacketFence::Controller::CaptivePortal;
use Moose;
use namespace::autoclean;
use pf::web::constants;
use URI::Escape qw(uri_escape uri_unescape);
use HTML::Entities;
use pf::config;
use pf::util;
use pf::Portal::Session;
use Apache2::Const -compile => qw(OK DECLINED HTTP_MOVED_TEMPORARILY);
use pf::web;
use pf::node;
use pf::useragent;
use pf::violation;
use Cache::FileCache;
use pf::sms_activation;

BEGIN { extends 'captiveportal::Base::Controller'; }

__PACKAGE__->config( namespace => 'captive-portal' );

our $USERAGENT_CACHE =
  new Cache::FileCache( { 'namespace' => 'CaptivePortal_UserAgents' } );

our $LOST_DEVICES_CACHE =
  new Cache::FileCache( { 'namespace' => 'CaptivePortal_LostDevices' } );

=head1 NAME

captiveportal::PacketFence::Controller::CaptivePortal - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

The root page (/)

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    $c->forward( Root => 'checkForViolation' );
    $c->forward( Root => 'checkIfPending' );
    $c->forward('checkIfCanRegistration');
    $c->forward('unknownState');
    $self->showError( $c,
        "Your network should be enabled within a minute or two. If it is not reboot your computer"
    );
}

sub checkIfCanRegistration : Private {
    my ( $self, $c ) = @_;
    my $portalSession = $c->portalSession;
    my $profile       = $c->profile;
    my $mac           = $portalSession->clientMac;
    my $unreg         = node_unregistered($mac);
    if ( $unreg && isenabled( $Config{'trapping'}{'registration'} ) ) {
        my $logger = $c->log;

        # Redirect to the billing engine if enabled
        if ( isenabled( $profile->getBillingEngine ) ) {
            $logger->info("$mac redirected to billing page");
            $c->detach( 'Pay', 'index' );
        }

        # Redirect to the guests self registration page if configured to do so
        elsif ( $profile->guestRegistrationOnly ) {
            $logger->info("$mac redirected to guests self registration page");
            $c->detach( 'Signup', 'index' );
        } elsif ( $Config{'registration'}{'nbregpages'} == 0 ) {
            $logger->info("$mac redirected to authentication page");
            $c->detach( 'Authenticate', 'index' );
        } else {
            $logger->info(
                "$mac redirected to multi-page registration process");
            $c->detach( 'Authenticate', 'next_page' );
        }
    }
}

sub unknownState : Private {
    my ( $self, $c ) = @_;
    my $portalSession      = $c->portalSession;
    my $mac                = $portalSession->clientMac;
    my $cached_lost_device = $LOST_DEVICES_CACHE->get($mac);

    # After 5 requests we won't perform re-eval for 5 minutes
    if ( !defined($cached_lost_device) || $cached_lost_device <= 5 ) {

        # set the cache, incrementing before on purpose (otherwise it's not hitting the cache)
        $LOST_DEVICES_CACHE->set( $mac, ++$cached_lost_device, "5 minutes" );

        $c->log->info(
            "MAC $mac shouldn't reach here. Calling access re-evaluation. "
              . "Make sure your network device configuration is correct." );
        pf::enforcement::reevaluate_access( $mac, 'redir.cgi',
            ( force => $TRUE ) );
    }
    $self->showError( $c,
        "Your network should be enabled within a minute or two. If it is not reboot your computer."
    );
}

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
