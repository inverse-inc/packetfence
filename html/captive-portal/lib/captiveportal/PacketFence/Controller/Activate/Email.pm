package captiveportal::PacketFence::Controller::Activate::Email;
use Moose;
use namespace::autoclean;

BEGIN { extends 'captiveportal::Base::Controller'; }

use Log::Log4perl;
use POSIX;

use pf::config;
use pf::activation qw($GUEST_ACTIVATION $SPONSOR_ACTIVATION);
use pf::node;
use pf::Portal::Session;
use pf::util qw(valid_mac);
use pf::web;
use pf::log;
use pf::web::guest 1.30;
use HTML::Entities;

# called last to allow redefinitions
use pf::web::custom;

use pf::authentication;
use pf::Authentication::constants;

=head1 NAME

captiveportal::PacketFence::Controller::Activate::Email - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $request = $c->request;
    my $code    = $request->param('code');
    my $logger  = $c->log;
    if ( defined $code ) {
        $c->forward( 'code', [$code] );
    }
}

sub code : Path : Args(1) {
    my ( $self, $c, $code ) = @_;
    my $portalSession = $c->portalSession;
    my $profile       = $c->profile;
    my $node_mac;
    my $request = $c->request;
    my $logger  = get_logger;

    # validate code
    my $activation_record = pf::activation::validate_code($code);
    if (  !defined($activation_record)
        || ref($activation_record) ne 'HASH'
        || !defined( $activation_record->{'type'} ) ) {

        $c->error(
                "The activation code provided is invalid."
              . " Reasons could be: it never existed, it was already used or has expired."
        );
        $c->detach;
    }

    # if we have a MAC, guest was on-site and we set that MAC in the session
    $node_mac = $activation_record->{'mac'};
    if ( defined($node_mac) ) {
        $portalSession->guestNodeMac($node_mac);
    }
    $c->stash( activation_record => $activation_record );

    # Email activated guests only need to prove their email was valid by clicking on the link.
    if ( $activation_record->{'type'} eq $GUEST_ACTIVATION ) {
        $c->forward('doEmailRegistration', [$code]);
    }

    #
    # Sponsor activated guests. We need the sponsor to authenticate before allowing access
    #
    elsif ( $activation_record->{'type'} eq $SPONSOR_ACTIVATION ) {
        $c->forward('doSponsorRegistration', [$code]);

    } else {

        $logger->info( "User has nothing to do here, redirecting to "
              . $Config{'trapping'}{'redirecturl'} );
        $c->response->redirect( $Config{'trapping'}{'redirecturl'} );
    }
}

=head2 login

TODO: documention

=cut

sub login : Private {
    my ( $self, $c ) = @_;
    $c->stash(
        template => $pf::web::guest::SPONSOR_LOGIN_TEMPLATE,
        username => encode_entities( $c->request->param("username") )
    );
}

=head2 doEmailRegistration

TODO: documention

=cut

sub doEmailRegistration : Private {
    my ( $self, $c, $code ) = @_;
    my $request           = $c->request;
    my $logger            = get_logger;
    my $activation_record = $c->stash->{activation_record};
    my $profile           = $c->profile;
    my $node_mac          = $c->portalSession->guestNodeMac;
    my ( $pid, $email ) = @{$activation_record}{ 'pid', 'contact_info' };
    my $auth_params = {
        'username'   => $pid,
        'user_email' => $email
    };

    my $email_type =
      pf::Authentication::Source::EmailSource->getDefaultOfType;
    my $source = $profile->getSourceByType($email_type);

    if ($source) {

        # if we have a MAC, guest was on-site and we need to proceed with registration
        if ( defined($node_mac) && valid_mac($node_mac) ) {

            # Setting access timeout and role (category) dynamically
            my $expiration =
              &pf::authentication::match( $source->{id},
                $auth_params, $Actions::SET_ACCESS_DURATION );

            if ( defined $expiration ) {
                $expiration = pf::config::access_duration($expiration);
            } else {
                $expiration =
                  &pf::authentication::match( $source->{id},
                    $auth_params, $Actions::SET_UNREG_DATE );
            }

            my $category =
              &pf::authentication::match( $source->{id},
                $auth_params, $Actions::SET_ROLE );

            $logger->debug(
                "Determined unregdate $expiration and category $category for email $email"
            );

            # change the unregdate of the node associated with the submitted code
            # FIXME
            node_modify(
                $node_mac,
                (   'unregdate' => $expiration,
                    'status'    => 'reg',
                    'category'  => $category,
                )
            );
            $c->stash(
                template   => $pf::web::guest::EMAIL_CONFIRMED_TEMPLATE,
                expiration => $expiration
            );
        } else {

            # if we don't have the MAC it means it's a preregister
            # guest generate a password and send an email with an
            # access code
            my %info = (
                'pid'     => $pid,
                'email'   => $email,
                'subject' => i18n_format(
                    "%s: Guest access confirmed!",
                    $Config{'general'}{'domain'}
                ),
                'currentdate' =>
                  POSIX::strftime( "%m/%d/%y %H:%M:%S", localtime )
            );

            # we create a temporary password using the actions from
            # the email authentication source;
            my $actions =
              &pf::authentication::match( $source->{id}, $auth_params );
            $info{'password'} =
              pf::temporary_password::generate( $pid, $actions );

            # send on-site guest credentials by email
            pf::web::guest::send_template_email(
                $pf::web::guest::TEMPLATE_EMAIL_EMAIL_PREREGISTRATION_CONFIRMED,
                $info{'subject'}, \%info
            );

            $c->stash(
                template => $pf::web::guest::EMAIL_PREREG_CONFIRMED_TEMPLATE,
                %info
            );
        }

        # code has been consumed, deactivate
        pf::activation::set_status_verified($code);
        $c->detach;
    } else {
        $logger->warn( "No active email source for profile "
              . $profile->getName
              . ", redirecting to "
              . $Config{'trapping'}{'redirecturl'} );
        $c->response->redirect( $Config{'trapping'}{'redirecturl'} );
    }
}

=head2 doSponsorRegistration

TODO: documention

=cut

sub doSponsorRegistration : Private {
    my ( $self, $c, $code ) = @_;
    my $logger            = get_logger;
    my $request           = $c->request;
    my $activation_record = $c->stash->{activation_record};
    my $portalSession     = $c->portalSession;
    my $node_mac          = $portalSession->guestNodeMac;
    my ( $pid, $email ) = @{$activation_record}{ 'pid', 'contact_info' };
    my $auth_params = {
        'username'   => $pid,
        'user_email' => $email
    };

    my $profile = $c->profile;
    my $sponsor_type =
      pf::Authentication::Source::SponsorEmailSource->getDefaultOfType;
    my $source = $profile->getSourceByType($sponsor_type);

    if ($source) {

        # if we have a username in session it means user has already authenticated
        # so we go ahead and allow the guest in
        if ( !defined( $c->session->{"username"} ) ) {

            # User is not logged and didn't provide username or password: show login form
            if (!(  $request->param("username") && $request->param("password")
                )
              ) {
                $logger->info(
                    "Sponsor needs to authenticate in order to activate guest. Guest token: $code"
                );
                $c->detach('login');
            }

            # User provided username and password: authenticate
            $c->forward(Authenticate => 'authenticationLogin');
            $c->detach('login') if $c->has_errors;
        }

        # handling log out (not exposed to the UI at this point)
        # TODO: if we ever expose it, we'll need to alter the form action to make sure to trim it
        # otherwise we'll submit our authentication but with ?action=logout so it'll delete the session right away
        if ( defined( $request->param("action") )
            && $request->param("action") eq "logout" ) {
            $c->session->{username} = undef;
            $c->detach('login');
        }

        # User is authenticated (session username exists OR auth_return == $TRUE above)
        $logger->debug( $c->session->{username}
              . " successfully authenticated. Activating sponsored guest" );

        my ( %info, $template );
        if ( defined($node_mac) ) {

            # If MAC is defined, it's a guest already here that we need to register
            my $node_info = node_attributes($node_mac);
            $pid = $node_info->{'pid'};
            if ( !defined($node_info) || ref($node_info) ne 'HASH' ) {

                $logger->warn(
                    "Problem finding more information about a MAC address ($node_mac) to enable guest access"
                );
                $self->showError(
                    "There was a problem trying to find the computer to register. The problem has been logged."
                );
            }
            if ( $node_info->{'status'} eq $pf::node::STATUS_REGISTERED ) {

                    $logger->warn(
                        "node mac: $node_mac has already been registered.");
                    $self->showError(
                        "The device with MAC address %s has already been authorized to your network.",
                        $node_mac
                    );
            }

            # register the node
            %info = %{$node_info};
            $c->forward( 'CaptivePortal' => 'webNodeRegister', [ $pid, %info ] );

            # populating variables used to send email
            $template =
              $pf::web::guest::TEMPLATE_EMAIL_GUEST_ON_REGISTRATION;
            $info{'subject'} = i18n_format(
                "%s: Guest network access enabled",
                $Config{'general'}{'domain'}
            );
        } elsif ( defined( $activation_record->{'pid'} ) ) {

             # If pid is set in activation record then we are activating a guest who pre-registered

            $pid = $activation_record->{'pid'};

            # populating variables used to send email
            $template =
              $pf::web::guest::TEMPLATE_EMAIL_SPONSOR_PREREGISTRATION;
            $info{'subject'} = i18n_format(
                "%s: Guest access request accepted",
                $Config{'general'}{'domain'}
            );
        }

        # TO:
        $info{'email'} = $pid;

        # username
        $info{'pid'} = $pid;
        $info{'cc'} =
          $Config{'guests_self_registration'}{'sponsorship_cc'};

        # we create a temporary password using the actions from the sponsor authentication source;
        # NOTE: When sponsoring a network access, the new user will be created (in the temporary_password table) using
        # the actions of the sponsor authentication source of the portal profile on which the *sponsor* has landed.
        my $actions = &pf::authentication::match( $source->{id},
            { username => $pid, user_email => $pid } );
        $info{'password'} =
          pf::temporary_password::generate( $pid, $actions );

        # prepare welcome email for a guest who registered locally
        $info{'currentdate'} =
          POSIX::strftime( "%m/%d/%y %H:%M:%S", localtime );

        pf::web::guest::send_template_email( $template, $info{'subject'},
            \%info );
        pf::activation::set_status_verified($code);

        # send to a success page
        $c->stash(
            template => $pf::web::guest::SPONSOR_CONFIRMED_TEMPLATE );
        $c->detach;
    } else {
        $logger->warn( "No active sponsor source for profile "
              . $profile->getName
              . ", redirecting to "
              . $Config{'trapping'}{'redirecturl'} );
        $c->response->redirect( $Config{'trapping'}{'redirecturl'} );
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
