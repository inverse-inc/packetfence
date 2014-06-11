package captiveportal::PacketFence::Controller::Activate::Sms;
use Moose;
use namespace::autoclean;
use Log::Log4perl;
use POSIX;
use URI::Escape::XS qw(uri_escape);

use pf::config;
use pf::iplog;
use pf::node;
use pf::Portal::Session;
use pf::util;
use pf::violation;
use pf::web;
use pf::web::guest;
use pf::activation;

# called last to allow redefinitions
use pf::web::custom;

use pf::authentication;
use pf::Authentication::constants;

BEGIN { extends 'captiveportal::Base::Controller' }

=head1 NAME

captiveportal::PacketFence::Controller::Activate::Sms - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $logger        = $c->log;
    my $request       = $c->request;
    my $portalSession = $c->portalSession;
    if ( $request->param("pin") ) {
        $logger->info("Entering guest authentication by SMS");
        my ( $auth_return, $err ) = $self->sms_validation($c);
        if ( $auth_return != 1 ) {
            $c->stash(
                txt_auth_error => i18n_format( $GUEST::ERRORS{$err} ) );
            $c->detach('showSmsConfirmation');
        }
        my $profile = $c->profile;
        my %info;
        $logger->info("Valid PIN -- Registering user");
        my $pid = $c->session->{"guest_pid"} || "admin";
        my $sms_type =
          pf::Authentication::Source::SMSSource->getDefaultOfType();
        my $source = $profile->getSourceByType($sms_type);
        my $auth_params = { 'username' => $pid };

        if ($source) {

            # Setting access timeout and role (category) dynamically
            $info{'unregdate'} =
              &pf::authentication::match( $source->{id}, $auth_params,
                $Actions::SET_ACCESS_DURATION );
            if ( defined $info{'unregdate'} ) {
                $info{'unregdate'} = pf::config::access_duration($info{'unregdate'});
            } else {
                $info{'unregdate'} =
                  &pf::authentication::match( $source->{id}, $auth_params,
                    $Actions::SET_UNREG_DATE );
            }
            $info{'category'} =
              &pf::authentication::match( $source->{id}, $auth_params,
                $Actions::SET_ROLE );

            $c->forward( 'CaptivePortal' => 'webNodeRegister', [ $pid, %info ] );

            # clear state that redirects to the Enter PIN page
            $c->session->{guest_pid} = undef;
            pf::activation::set_status_verified($request->param('pin'));
            $c->detach( 'CaptivePortal', 'endPortalSession' );
        } else {
            $logger->warn( "No active sms source for profile "
                  . $profile->getName
                  . ", redirecting to "
                  . $Config{'trapping'}{'redirecturl'} );
            $c->response->redirect( $Config{'trapping'}{'redirecturl'} );
        }
    } elsif ( $request->param("action_confirm") ) {
        $c->forward('showSmsConfirmation');
    } else {
        $c->detach( 'Authenticate' => 'next_page' );
    }
}

=head2 showSmsConfirmation

TODO: documention

=cut

sub showSmsConfirmation : Private {
    my ( $self, $c ) = @_;
    $c->stash(
        template => 'guest/sms_confirmation.html',
        post_uri => '/activate/sms',
    );
    $c->detach;
}

sub sms_validation {
    my ( $self, $c ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # no form was submitted, assume first time
    my $pin = $c->request->param("pin");
    if ($pin) {
        $c->log->info("Mobile phone number validation attempt");
        if ( pf::activation::validate_code($pin) ) {
            return ( $TRUE, 0 );
        } else {
            return ( $FALSE, $GUEST::ERROR_INVALID_PIN );
        }
    } else {

        # this won't display an error
        return ( $FALSE, 0 );
    }
}

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
