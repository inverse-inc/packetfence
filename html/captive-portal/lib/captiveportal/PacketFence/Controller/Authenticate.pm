package captiveportal::PacketFence::Controller::Authenticate;

use Moose;
use namespace::autoclean;
use pf::config;
use pf::web qw(i18n);
use pf::node;
use pf::util;
use pf::locationlog;
use pf::authentication;
use HTML::Entities;
use List::MoreUtils qw(any);
use pf::config;

BEGIN { extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::PacketFence::Controller::Authenticate - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

__PACKAGE__->config(
    {   action_args => {
            index => {
                valid_modes => {
                    aup        => 'aup',
                    status     => 'status',
                    release    => 'release',
                    next_page  => 'next_page',
                    deregister => 'deregister',
                }
            }
        }
    }
);

=head1 METHODS

=head2 begin

=cut

sub begin : Private {
    my ( $self, $c ) = @_;
    $c->forward(CaptivePortal => 'validateMac');
}

=head2 index

=cut

sub index : Path : Args(0) {
    my ( $self, $c ) = @_;
    my $mode   = $c->request->param('mode');
    if ( defined $mode ) {
        my $path = $self->modeToPath( $c, $mode );
        $c->go($path);
    } else {
        $c->detach('login');
    }
}

sub modeToPath {
    my ( $self, $c, $mode ) = @_;
    my $action = $c->action;
    my $path   = 'default';
    if ( exists $action->{valid_modes}{$mode} ) {
        $path = $action->{valid_modes}{$mode};
    }
    return $path;
}

sub default : Path {
    my ( $self, $c ) = @_;
    $c->error("error: incorrect mode");
}

sub next_page : Local : Args(0) {
    my ( $self, $c ) = @_;
    my $profile = $c->profile;
    my $pagenumber = $c->request->param('page');

    $pagenumber = 1 if ( !defined($pagenumber) );
    my $last_page = $profile->nbregpages;

    if (   ( $pagenumber >= 1 )
        && ( $pagenumber <= $last_page ) ) {

        $c->stash( reg_page_content_file => "register_$pagenumber.html", );

        # generate list of locales
        my $authorized_locale_txt = $Config{'general'}{'locale'};
        my @authorized_locale_array = split( /,/, $authorized_locale_txt );
        my @locales;
        if ( scalar(@authorized_locale_array) == 1 ) {
            push @locales,
              { name => 'locale', value => $authorized_locale_array[0] };
        } else {
            foreach my $authorized_locale (@authorized_locale_array) {
                push @locales,
                  { name => 'locale', value => $authorized_locale };
            }
        }
        $c->stash->{'list_locales'} = \@locales;

        if ( $pagenumber == $last_page ) {
            $c->stash->{'button_text'} =
              $Config{'registration'}{'button_text'};
            if($profile->guestRegistrationOnly) {
                $c->stash->{'form_action'} = '/signup';
            } else {
                $c->stash->{'form_action'} = '/authenticate';
            }
        } else {
            $c->stash->{'button_text'} = "Next page";
            $c->stash->{'form_action'} =
              '/authenticate?mode=next_page&page=' . ( int($pagenumber) + 1 );
        }

        $c->stash->{template} = 'register.html';
    } else {
        $c->error( "error: invalid page number" );
    }
}

sub deregister : Local : Args(0) {
    my ( $self, $c ) = @_;
    $c->forward('authenticationLogin');
    unless ( $c->has_errors ) {
        my $portalSession = $c->portalSession;
        my $mac           = $portalSession->clientMac;
        my $node_info     = node_view($mac);
        my $pid           = $node_info->{'pid'};
        if ( $c->session->{username} eq $pid ) {
            pf::node::node_deregister($mac);
        } else {
            $c->error( "error: access denied not owner" );
        }
    } else {
        $c->forward('login');
    }
}

sub authenticateUser {
    my ( $self, $portalSession ) = @_;
}

sub aup : Local : Args(0) {
    my ( $self, $c ) = @_;
    $c->detach( 'Aup', 'index' );
}

sub status : Local : Args(0) {
    my ( $self, $c ) = @_;
    $c->detach( 'Status', 'index' );
}

sub login : Local : Args(0) {
    my ( $self, $c ) = @_;
    if ( $c->request->method eq 'POST' ) {

        # External authentication
        $c->forward('validateLogin');
        $c->forward('authenticationLogin');
        $c->forward('postAuthentication');
        $c->forward( 'CaptivePortal' => 'webNodeRegister', [$c->stash->{info}->{pid}, %{$c->stash->{info}}] );
        $c->forward( 'CaptivePortal' => 'endPortalSession' );
    }

    # Return login
    $c->forward('showLogin');

}

=head2 postAuthentication

TODO: documention

=cut

sub postAuthentication : Private {
    my ( $self, $c ) = @_;
    my $logger = $c->log;
    $c->detach('showLogin') if $c->has_errors;
    my $portalSession = $c->portalSession;
    my $session = $c->session;
    my $profile = $c->profile;
    my $info = $c->stash->{info} || {};
    my $source_id = $session->{source_id};
    my $pid = $session->{"username"};
    $pid = $default_pid if _no_username($c->profile);
    $info->{pid} = $pid;
    my $params = { username => $pid };
    my $mac = $portalSession->clientMac;

    # TODO : add current_time and computer_name
    my $locationlog_entry = locationlog_view_open_mac($mac);
    if ($locationlog_entry) {
        $params->{connection_type} = $locationlog_entry->{'connection_type'};
        $params->{SSID}            = $locationlog_entry->{'ssid'};
    }

    # obtain node information provided by authentication module. We need to get the role (category here)
    # as web_node_register() might not work if we've reached the limit
    my $value =
      &pf::authentication::match( $source_id, $params, $Actions::SET_ROLE );

    $logger->trace("Got role '$value' for username $pid");

    # This appends the hashes to one another. values returned by authenticator wins on key collision
    if ( defined $value ) {
        $info->{category} = $value;
    }

    # If an access duration is defined, use it to compute the unregistration date;
    # otherwise, use the unregdate when defined.
    $value =
      &pf::authentication::match( $source_id, $params,
        $Actions::SET_ACCESS_DURATION );
    if ( defined $value ) {
        $value = pf::config::access_duration($value);
        $logger->trace("Computed unreg date from access duration: $value");
    } else {
        $value =
          &pf::authentication::match( $source_id, $params,
            $Actions::SET_UNREG_DATE );
    }
    if ( defined $value ) {
        $logger->trace("Got unregdate $value for username $pid");
        $info->{unregdate} = $value;
    }
    $info->{source} = $source_id;
    $info->{portal} = $profile->getName;
    $c->stash->{info} = $info;
}

sub validateLogin : Private {
    my ( $self, $c ) = @_;
    my $logger  = $c->log;
    my $profile = $c->profile;
    $logger->debug("form validation attempt");

    my $request = $c->request;
    my $no_password_needed =
      any { $_ eq 'null' } @{ $profile->getGuestModes };
    my $no_username_needed = _no_username($profile);

    if (   ( $request->param("username") || $no_username_needed )
        && ( $request->param("password") || $no_password_needed ) ) {

        # acceptable use pocliy accepted?
        my $aup_signed = $request->param("aup_signed");
        if (   !defined($aup_signed)
            || !$aup_signed ) {
            $c->error('You need to accept the terms before proceeding any further.');
            $c->detach('showLogin');
        }
    } else {
        $c->detach('showLogin');
    }
}

sub authenticationLogin : Private {
    my ( $self, $c ) = @_;
    my $logger  = $c->log;
    my $session = $c->session;
    my $request = $c->request;
    my $profile = $c->profile;
    my $portalSession = $c->portalSession;
    my $mac           = $portalSession->clientMac;

    $logger->trace("authentication attempt");
    my $local;
    if ($request->{'match'} eq "status/login") {
        use pf::person;
        my $person_info = pf::person::person_view($request->param("username"));
        my $source = pf::authentication::getAuthenticationSource($person_info->{source});
        if (defined($source) && $source->{'class'} eq 'external') {
            # Source is external, we have to use local source to authenticate
            $local = '1';
        }
        my $options = {
            'portal' => $person_info->{portal},
        };
        $profile = pf::Portal::ProfileFactory->instantiate( $mac, $options);
    }

    my @sources;
    if ($local) {
        @sources = pf::authentication::getAuthenticationSource('local');
    } else {
        @sources =
            ( $profile->getInternalSources, $profile->getExclusiveSources );
    }

    my $username = $request->param("username");
    my $password = $request->param("password");

    # validate login and password
    my ( $return, $message, $source_id ) =
      pf::authentication::authenticate( $username, $password, @sources );
    if ( defined($return) && $return == 1 ) {
        # save login into session
        $c->session->{"username"} = $request->param("username");
        $c->session->{source_id} = $source_id;
    } else {
        $c->error($message);
    }
}

sub _no_username {
    my ($profile) = @_;
    return any { $_->type eq 'Null' && isdisabled( $_->email_required ) } $profile->getSourcesAsObjects;
}

sub showLogin : Private {
    my ( $self, $c ) = @_;
    my $profile    = $c->profile;
    my $guestModes = $profile->getGuestModes;
    my $guest_allowed =
      any { is_in_list( $_, $guestModes ) } $SELFREG_MODE_EMAIL,
      $SELFREG_MODE_SMS, $SELFREG_MODE_SPONSOR;
    my $request = $c->request;
    if ( $c->has_errors ) {
        $c->stash->{txt_auth_error} = join(' ', grep { ref ($_) eq '' } @{$c->error});
        $c->clear_errors;
    }
    $c->stash(
        template        => 'login.html',
        username        => encode_entities( $request->param("username") ),
        null_source     => is_in_list( $SELFREG_MODE_NULL, $guestModes ),
        oauth2_github   => is_in_list( $SELFREG_MODE_GITHUB, $guestModes ),
        oauth2_google   => is_in_list( $SELFREG_MODE_GOOGLE, $guestModes ),
        no_username     => _no_username($profile),
        oauth2_facebook => is_in_list( $SELFREG_MODE_FACEBOOK, $guestModes ),
        oauth2_linkedin => is_in_list( $SELFREG_MODE_LINKEDIN, $guestModes ),
        oauth2_win_live => is_in_list( $SELFREG_MODE_WIN_LIVE, $guestModes ),
        guest_allowed   => $guest_allowed,
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
