package captiveportal::PacketFence::DynamicRouting::Module::RootSSO;

=head1 NAME

DynamicRouting::Module::RootSSO

=head1 DESCRIPTION

Root module used to authenticate a user for an external application (the admin
interface). Once the chained modules complete, the resulting node info is stored
under a random token and the browser is redirected to the caller's callback URL
with that token. The caller then exchanges the token on /portaltoken.

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Chained';
with 'captiveportal::Role::Routed';

has '+route_map' => (default => sub {
    tie my %map, 'Tie::IxHash', (
        '/logout' => \&logout,
    );
    return \%map;

});

use pf::log;
use pf::util;
use pf::CHI;
use pf::config qw(%Config);
use pf::constants qw($TRUE);
use Bytes::Random::Secure;
use List::MoreUtils qw(any uniq);
use URI;

=head2 cache

The cache namespace where the tokens are stored. Must match the namespace read by the token endpoint.

=cut

sub cache { return pf::CHI->new(namespace => 'portaladmin'); }

=head2 sso_config_section

The pf.conf section holding the SSO settings for this root module

=cut

sub sso_config_section { return 'admin_login' }

has '+parent' => (required => 0);

=head2 around done

Once this is done, we release the user on the network

=cut

around 'done' => sub {
    my ($orig, $self) = @_;
    if($self->execute_actions()){
        $self->release();
    }
    else {
        $self->app->reset_session();
        $self->redirect_root();
    }
};

=head2 logout

Logout of the captive portal

=cut

sub logout {
    my ($self) = @_;
    my $callback = $self->app->session->{callback};
    $self->app->reset_session;
    if (defined $callback) {
        return $self->app->redirect($callback."?error=canceled");
    }
    return $self->redirect_root();
}

=head2 release

Reevaluate the access of the user and show the release page

=cut

sub release {
    my ($self) = @_;
    my $callback = $self->app->session->{callback};
    unless (defined $callback) {
        get_logger->error("No callback URL in the session, cannot hand the SSO token back to the caller");
        $self->app->reset_session();
        return $self->app->error("Missing callback URL. Please restart the login from the application.");
    }
    return $self->app->redirect($callback."?token=".$self->{root_session_token});
}

=head2 allowed_callback_hosts

The hosts a callback URL may point to: the configured allow list, the host of the SSO base URL and this server's FQDN

=cut

sub allowed_callback_hosts {
    my ($self) = @_;
    my $section = $Config{$self->sso_config_section} // {};
    my @hosts = split(/\s*,\s*/, $section->{sso_callback_allowed_hosts} // '');
    if (my $base = $section->{sso_base_url}) {
        my $base_host = eval { URI->new($base)->host };
        push @hosts, $base_host if defined $base_host;
    }
    push @hosts, $Config{general}{hostname}.".".$Config{general}{domain};
    return [ uniq map { lc } grep { defined $_ && length $_ } @hosts ];
}

=head2 validate_callback

Returns the callback URL if it is an absolute http(s) URL whose host is allowed, undef otherwise

=cut

sub validate_callback {
    my ($self, $callback) = @_;
    my $uri = eval { URI->new($callback) };
    my $scheme = defined $uri ? ($uri->scheme // '') : '';
    unless ($scheme eq 'http' || $scheme eq 'https') {
        get_logger->warn("Refusing SSO callback '$callback': not an absolute http(s) URL");
        return undef;
    }
    my $host = lc($uri->host // '');
    my $allowed = $self->allowed_callback_hosts;
    unless (any { $_ eq $host } @$allowed) {
        get_logger->warn("Refusing SSO callback '$callback': host '$host' is not in the allowed list (".join(",", @$allowed).")");
        return undef;
    }
    return $callback;
}

=head2 execute_child

Execute the flow for this module

=cut

sub execute_child {
    my ($self) = @_;
    if (my $callback = $self->app->request->param('callback')) {
        my $valid = $self->validate_callback($callback);
        unless (defined $valid) {
            $self->app->reset_session();
            return $self->app->error("Invalid callback URL. Please contact your local support staff.");
        }
        $self->app->session->{callback} = $valid;
    }

    $self->SUPER::execute_child();
}

=head2 execute_actions

Store the new node info under a random token for the callback owner to fetch

=cut

sub execute_actions {
    my ($self) = @_;
    my $rand = Bytes::Random::Secure->new(
            Bits        => 64,
            NonBlocking => 1,
        );
    my $token = unpack("H*", $rand->bytes(32));
    $self->cache->set($token, $self->new_node_info);
    $self->{root_session_token} = $token;
    return $TRUE;
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

