package captiveportal::PacketFence::Controller::Activate::Sms;
use Moose;
use namespace::autoclean;
use Log::Log4perl;
use POSIX;
use URI::Escape::XS qw(uri_escape);

use pf::constants;
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
            utf8::decode($c->stash->{'txt_auth_error'});
            $c->detach('showSmsConfirmation');
        }
        my $profile = $c->profile;
        my %info;
        $logger->info("Valid PIN -- Registering user");
        my $pid = $c->session->{"guest_pid"} || "default";
        my $sms_type = pf::Authentication::Source::SMSSource->getDefaultOfType();
        my $source = $profile->getSourceByType($sms_type) || $profile->getSourceByTypeForChained($sms_type);
        my $auth_params = { 'username' => $pid, 'user_email' => $pid };

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

            $c->session->{"username"} = $pid;
            $c->session->{source_id} = $source->{id};
            $c->stash->{info}=\%info;
            $c->stash->{sms_pin} = $request->param_encoded("pin");  # We are putting the SMS PIN in stash to use it as a password in case we create a local account
            $c->forward('Authenticate' => 'postAuthentication');
            $c->forward('Authenticate' => 'createLocalAccount', [$auth_params]) if ( isenabled($source->{create_local_account}) );
            $c->forward('CaptivePortal' => 'webNodeRegister', [$pid, %{$c->stash->{info}}]);

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
    my ($self, $c) = @_;
    my $logger = $c->log;

    # no form was submitted, assume first time
    my $pin = $c->request->param("pin");
    if ($pin) {
        $logger->debug("Mobile phone number validation attempt");
        my $portalSession = $c->portalSession;
        if ($self->reached_retry_limit($c, 'sms_retries', $portalSession->profile->{_sms_pin_retry_limit})) {
            my $mac = $portalSession->clientMac;
            $logger->info("Max tries reached invalidating code for $mac");
            pf::activation::invalidate_codes_for_mac($mac,'sms');
            $c->stash(txt_validation_error => i18n_format($GUEST::ERRORS{$GUEST::ERROR_MAX_RETRIES}));
            utf8::decode($c->stash->{'txt_auth_error'});
            $c->detach(Signup => 'index');
        }
        if (pf::activation::validate_code($pin)) {
            return ($TRUE, 0);
        }
        else {
            return ($FALSE, $GUEST::ERROR_INVALID_PIN);
        }
    }
    else {
        # this won't display an error
        return ($FALSE, 0);
    }
}

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
