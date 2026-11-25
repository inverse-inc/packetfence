#!/usr/bin/perl

=head1 NAME

MAC

=head1 DESCRIPTION

Browser session ID of the captive portal

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 15;
use Test::NoWarnings;

use Catalyst::Plugin::Session::State::MAC;

my $session_id = 'a' x 40;
my $cookie_id = 'b' x 40;

# A Catalyst context with a request, a stash and the cookie methods
{
    package test_request;
    sub new { my ($class, %args) = @_; bless { parameters => $args{parameters} // {}, path => $args{path}, cookie => $args{cookie} }, $class }
    sub path { $_[0]{path} }
    sub cookie { my ($self) = @_; defined $self->{cookie} ? test_cookie->new($self->{cookie}) : undef }

    package test_cookie;
    sub new { bless { value => $_[1] }, $_[0] }
    sub value { $_[0]{value} }

    package test_response;
    sub new { bless { cookies => {} }, shift }
    sub cookies { $_[0]{cookies} }

    package test_context;
    our @ISA = ('Catalyst::Plugin::Session::State::MAC');
    sub new { my ($class, %args) = @_; bless { request => test_request->new(%args), response => test_response->new, stash => {} }, $class }
    sub request { $_[0]{request} }
    sub response { $_[0]{response} }
    sub stash { $_[0]{stash} }
    sub generate_session_id { 'c' x 40 }
    sub cookie_is_rejecting { 0 }
    sub _session_plugin_config { { cookie_name => 'CGISESSION' } }
    sub make_session_cookie { my ($self, $id) = @_; return { value => $id } }
}

sub context { test_context->new(@_) }

is(context(path => 'saml/assertion', parameters => { RelayState => $session_id })->relay_state_session_id, $session_id, 'RelayState on the SAML assertion');
is(context(path => '/mfa', parameters => { RelayState => $session_id })->relay_state_session_id, $session_id, 'RelayState on the MFA callback');
is(context(path => 'status', parameters => { RelayState => $session_id })->relay_state_session_id, undef, 'RelayState is ignored on the status page');
is(context(path => 'captive-portal', parameters => { RelayState => $session_id })->relay_state_session_id, undef, 'RelayState is ignored on the portal');
is(context(path => 'saml/assertion', parameters => { RelayState => 'not-a-session-id' })->relay_state_session_id, undef, 'RelayState must be a session ID');
is(context(path => 'saml/assertion', parameters => { RelayState => [$session_id, $session_id] })->relay_state_session_id, undef, 'RelayState must be a single value');

is(context(path => 'status', parameters => { RelayState => $session_id }, cookie => $cookie_id)->browser_session_id, $cookie_id, 'the cookie is used outside of the SSO callbacks');
is(context(path => 'saml/assertion', parameters => { RelayState => $session_id }, cookie => $cookie_id)->browser_session_id, $session_id, 'the RelayState is used on the SSO callbacks');
is(context(path => 'status')->browser_session_id, 'c' x 40, 'a session ID is generated without cookie');

{
    my $c = context(path => 'status', cookie => $cookie_id);
    $c->stash->{browser_session_id} = 'd' x 40;
    is($c->browser_session_id, 'd' x 40, 'a renewed browser session ID in the stash is used before the cookie');
}

{
    my $c = context(path => 'saml/assertion', parameters => { RelayState => $session_id });
    $c->update_session_cookie(1);
    ok(!exists $c->response->cookies->{CGISESSION}, 'the cookie is not written from the RelayState');
}

{
    my $c = context(path => 'status', parameters => { RelayState => $session_id }, cookie => $cookie_id);
    $c->update_session_cookie(1);
    is($c->response->cookies->{CGISESSION}{value}, $cookie_id, 'the cookie keeps its session ID outside of the SSO callbacks');
}

{
    my $c = context(path => 'status');
    $c->update_session_cookie(1);
    is($c->response->cookies->{CGISESSION}{value}, 'c' x 40, 'a generated session ID is written in the cookie');
}

{
    my $c = context(path => 'status');
    $c->stash->{browser_session_id} = 'd' x 40;
    $c->update_session_cookie(1);
    is($c->response->cookies->{CGISESSION}{value}, 'd' x 40, 'a renewed session ID is written in the cookie');
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
