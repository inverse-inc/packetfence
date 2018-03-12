package captiveportal::PacketFence::Controller::Authenticate;

use Moose;
use namespace::autoclean;
use pf::constants;
use pf::constants::eap_type qw($EAP_TLS);
use pf::constants::Connection::Profile qw($DEFAULT_PROFILE);
use pf::constants::realm;
use pf::config qw(%Profiles_Config);;
use pf::web qw(i18n i18n_format);
use pf::node;
use pf::util;
use pf::config::util;
use pf::locationlog;
use pf::authentication;
use pf::Authentication::constants;
use HTML::Entities;
use List::MoreUtils qw(any uniq all);
use pf::config;
use pf::auth_log;
use pf::person;
use Email::Valid;

BEGIN { extends 'captiveportal::Base::Controller'; }

=head1 NAME

captiveportal::PacketFence::Controller::Authenticate - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

=head1 METHODS

=head2 begin

=cut

=head2 setupMatchParams

setup the parameters to match against the rules in the sources to apply actions

=cut

sub setupMatchParams : Private {
    my ( $self, $c ) = @_;
    my $portalSession = $c->portalSession;
    my $pid = $c->stash->{info}->{pid};
    my $mac = $portalSession->clientMac;
    my $params = { username => $pid, mac => $mac };

    # TODO : add current_time and computer_name
    my $locationlog_entry = locationlog_view_open_mac($mac);
    if ($locationlog_entry) {
        $params->{connection_type} = $locationlog_entry->{'connection_type'};
        $params->{SSID}            = $locationlog_entry->{'ssid'};
        $params->{realm}           = $locationlog_entry->{'realm'};
    }
    $c->stash->{matchParams} = $params;
}

sub verifyAup : Private {
    my ( $self, $c ) = @_;
    my $request = $c->request;
    my $aup_status = $request->param("aup_signed");
    if ( !defined $aup_status ) {
        $c->error("The AUP was not signed"); 
    }
}

sub authenticationLogin : Private {
    my ( $self, $c ) = @_;
    my $logger  = $c->log;
    my $request = $c->request;
    my $profile = $c->profile;
    my $portalSession = $c->portalSession;
    my $mac           = $portalSession->clientMac;
    my ( $return, $message, $source_id, $extra );
    $logger->debug("authentication attempt");

    if ($request->{'match'} eq "status/login") {
        my $person_info = pf::person::person_view($request->param("username"));
        if($person_info) {
            my $source = pf::authentication::getAuthenticationSource($person_info->{source});
            if (defined($source) && $source->{'class'} eq 'external') {
                # Source is external, we have to use local source to authenticate
                $c->stash( use_local_source => 1 );
            }
            my $portal = $person_info->{portal};
            unless (defined $portal && length($portal) && exists $Profiles_Config{$portal}) {
                $portal = $DEFAULT_PROFILE;
            }
            my $options = {
                portal => $portal,
            };
            $profile = pf::Connection::ProfileFactory->instantiate( $mac, $options);
        }
    }
    $c->stash( profile => $profile );


    my $username = _clean_username($request->param("username"));
    my ($stripped_username, $realm) = strip_username($username);
    my $password = $request->param("password");

    my $sources = $self->getSources($c, $username, $realm);

    # validate login and password
    ( $return, $message, $source_id, $extra ) =
      pf::authentication::authenticate( {
              'username' => $username, 
              'password' => $password, 
              'rule_class' => $Rules::AUTH,
              'context' => $pf::constants::realm::PORTAL_CONTEXT,
          }, @{$sources} );
    if ( defined($return) && $return == 1 ) {
        pf::auth_log::record_auth($source_id, $portalSession->clientMac, $username, $pf::auth_log::COMPLETED, $profile->name);
        # save login into session
        $c->user_session->{username} = $username // $default_pid;
        $c->user_session->{source_id} = $source_id;
        $c->user_session->{source_match} = $source_id;
        $c->user_session->{extra} = $extra;
        if(!person_exist($username)){
            person_add($username);
        }
        # Logging USER/IP/MAC of the just-authenticated user
        $logger->info("Successfully authenticated ".$username."/".$portalSession->clientIP->normalizedIP."/".$portalSession->clientMac);
    } else {
        pf::auth_log::record_auth(join(',',map { $_->id } @{$sources}), $portalSession->clientMac, $username, $pf::auth_log::FAILED, $profile->name);
        $c->error($message);
    }
}

=head2 getSources

Return the source to use to login

=cut

sub getSources : Private {
    my ($self,$c,$stripped_username,$realm) = @_;
    my @sources;
    my $use_local_source = $c->stash->{use_local_source};
    my $profile = $c->stash->{profile};

    if ($use_local_source) {
        @sources = pf::authentication::getAuthenticationSource('local');
    } else {
        #If we try to validate a sponsor access then use all Internal Sources
        if ($c->request->{'match'} =~ "activate/email") {
            @sources = @{pf::authentication::getInternalAuthenticationSources()};
        } else {
            @sources =
                ( $profile->getInternalSources, $profile->getExclusiveSources );
        }
    }

    my $realm_source = get_realm_authentication_source($stripped_username, $realm, \@sources);
    if (ref($realm_source) eq 'ARRAY') {
        $c->log->info("Realm source is part of the connection profile sources. Using it as the only auth source.");
        return ($realm_source);
    }
    return \@sources;
}

sub _clean_username {
    my ($username) = @_;
    return $username unless defined $username;
    # Do cleaning that could be related to a human error input ( like a space after the username )

    # This removes trailing and leading whitespaces
    $username =~ s/^\s+|\s+$//g ;

    return $username;
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
