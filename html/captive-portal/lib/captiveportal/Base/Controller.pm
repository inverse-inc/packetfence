package captiveportal::Base::Controller;

=head1 NAME

captiveportal::Base::Controller add documentation

=cut

=head1 DESCRIPTION

captiveportal::Base::Controller

=cut

use Moose;
use Moose::Util qw(apply_all_roles);
use namespace::autoclean;
use pf::authentication;
use pf::config qw(%Config);
use pf::enforcement qw(reevaluate_access);
use pf::ip4log;
use pf::node
  qw(node_attributes node_modify node_register node_view is_max_reg_nodes_reached);
use pf::util;
use pf::security_event qw(security_event_count);
use pf::web::constants;
use pf::web;
use pf::CHI;
use URI::Escape qw(uri_escape);
BEGIN { extends 'Catalyst::Controller'; }

=head2 ssoLoginEnabled

Whether the portal single sign-on ([self_reg_login]) is enabled for the self-service and sponsor pages

=cut

sub ssoLoginEnabled {
    return isenabled($Config{self_reg_login}{sso_status}) ? 1 : 0;
}

=head2 ssoPasswordLoginAllowed

Whether a username/password login is still offered on a page that supports the portal single sign-on

=cut

sub ssoPasswordLoginAllowed {
    my ($self) = @_;
    return 1 unless $self->ssoLoginEnabled;
    return isenabled($Config{self_reg_login}{allow_username_password}) ? 1 : 0;
}

=head2 ssoCache

The cache where the SelfRegSSO root module stores its tokens

=cut

sub ssoCache { return pf::CHI->new(namespace => 'portalselfreg'); }

=head2 stashSsoLogin

Stash what a login template needs to offer the single sign-on: sso_login_url (SelfRegSSO login path with this
page as callback), sso_login_text and allow_username_password. Also turns the ?error= of a cancelled SSO into
txt_auth_error.

=cut

sub stashSsoLogin {
    my ($self, $c, $callback_path) = @_;
    if ( !$c->stash->{txt_auth_error} && ( my $error = $c->request->param("error") ) ) {
        $c->stash->{txt_auth_error} = $error eq "canceled" ? "The single sign-on login was canceled." : "The single sign-on login failed.";
    }
    if ( $self->ssoLoginEnabled ) {
        my $sso = $Config{self_reg_login};
        my $callback = $c->request->uri->clone;
        $callback->scheme("https");
        $callback->path($callback_path) if defined $callback_path;
        $callback->query(undef);
        $callback->fragment(undef);
        $c->stash(
            sso_login_url  => $sso->{sso_base_url} . $sso->{sso_login_path} . "?callback=" . uri_escape($callback->as_string),
            sso_login_text => $sso->{sso_login_text} || "Single Sign On",
        );
    }
    $c->stash( allow_username_password => $self->ssoPasswordLoginAllowed );
}

=head2 loginFromSsoToken

Authenticate the user from the single-use token handed back by the SelfRegSSO root module.
Populates the user session like Authenticate::authenticationLogin and keeps the token info
under sso_login. Sets a Catalyst error when the token is invalid.

=cut

sub loginFromSsoToken {
    my ($self, $c, $token) = @_;
    my $cache = $self->ssoCache;
    my $info = $cache->get($token);
    $cache->remove($token) if defined $info;
    unless ( ref($info) eq 'HASH' && defined $info->{pid} && defined $info->{source_id} ) {
        $c->log->warn("Invalid or expired portal SSO token");
        $c->error("Your single sign-on session is invalid or has expired. Please try again.");
        return 0;
    }
    $c->log->info("User $info->{pid} authenticated through single sign-on with source $info->{source_id}");
    $c->user_session->{username}     = $info->{pid};
    $c->user_session->{source_id}    = $info->{source_id};
    $c->user_session->{source_match} = $info->{source_id};
    $c->user_session->{sso_login}    = $info;
    return 1;
}

sub showError {
    my ( $self, $c, $error, @args ) = @_;
    my $text_message;
    if ( @args ) {
        $text_message = i18n_format($error, @args);
    } else {
        $text_message = i18n($error);
    }
    utf8::decode($text_message);
    $c->stash(
        template    => 'error.html',
        message => $text_message,
    );
    $c->detach;
}

=head2 reached_retry_limit

Test if the retry limit has been reached for a session key
If the max is undef or 0 then check is disabled

=cut

sub reached_retry_limit {
    my ( $self, $c, $retry_key, $max ) = @_;
    return 0 unless $max;
    my $cache = $c->user_cache;
    my $retries = $cache->get($retry_key) || 1;
    $retries++;
    $cache->set($retry_key,$retries,$c->profile->{_block_interval});
    return $retries > $max;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

1;
