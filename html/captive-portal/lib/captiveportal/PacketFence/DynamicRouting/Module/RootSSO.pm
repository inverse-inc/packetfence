package captiveportal::PacketFence::DynamicRouting::Module::RootSSO;

=head1 NAME

DynamicRouting::RootModule

=head1 DESCRIPTION

Root module for Dynamic Routing

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
use pf::constants qw($TRUE $FALSE);
use pf::config qw(%Config $fqdn $management_network);
use pf::cluster;
use Bytes::Random::Secure;
use Sys::Hostname ();
use URI;

sub cache { return pf::CHI->new(namespace => 'portaladmin'); }

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
        my $callback = $self->app->session->{callback};
        $self->app->reset_session();
        if (defined($callback)) {
            $self->app->redirect($callback."?error=denied");
        }
        else {
            $self->redirect_root();
        }
    }
};

=head2 logout

Logout of the captive portal

=cut

sub logout {
    my ($self) = @_;
    my $callback = $self->app->session->{callback};
    $self->app->reset_session;
    $self->app->redirect($callback."?error=canceled");
}

=head2 release

Reevaluate the access of the user and show the release page

=cut

sub release {
    my ($self) = @_;
    my $callback = $self->app->session->{callback};
    # Start over on the next SSO so the user is authenticated (and the rules evaluated) again
    $self->app->reset_session();
    unless (defined($callback)) {
        get_logger->error("Admin SSO completed without a valid callback, not sending the token");
        return $self->redirect_root();
    }
    return $self->app->redirect($callback."?token=".$self->{root_session_token});
}

=head2 execute_child

Execute the flow for this module

=cut

sub execute_child {
    my ($self) = @_;
    my $callback = $self->app->request->param('callback');
    if ($callback) {
        if (is_valid_callback($callback)) {
            $self->app->session->{callback} = $callback;
        }
        else {
            get_logger->warn("Ignoring admin SSO callback '$callback': it isn't an admin URL of this server. Add its host to admin_login.sso_allowed_callback_hosts if needed.");
        }
    }

    $self->SUPER::execute_child();
}

=head2 allowed_callback_hosts

The hosts the admin SSO token can be sent to: the names and management addresses of this server (and of the cluster), the SSO base URL host and admin_login.sso_allowed_callback_hosts

=cut

sub allowed_callback_hosts {
    my @hosts = ($fqdn, $Config{general}{hostname}, Sys::Hostname::hostname());
    if ($management_network) {
        push @hosts, $management_network->tag('ip'), $management_network->tag('vip');
    }
    if ($pf::cluster::cluster_enabled) {
        push @hosts, pf::cluster::management_cluster_ip();
        push @hosts, map { ($_->{host}, $_->{management_ip}) } pf::cluster::config_enabled_servers();
    }
    if (my $sso_base_url = $Config{admin_login}{sso_base_url}) {
        my $uri = eval { URI->new($sso_base_url) };
        push @hosts, $uri->host if $uri && $uri->can('host');
    }
    push @hosts, split(/\s*,\s*/, $Config{admin_login}{sso_allowed_callback_hosts} // '');
    return map { lc($_) } grep { defined($_) && $_ ne '' } @hosts;
}

=head2 is_valid_callback

Whether the callback is an admin URL of this server, the token is only sent there

=cut

sub is_valid_callback {
    my ($callback) = @_;
    my $uri = eval { URI->new($callback) };
    return $FALSE unless $uri && $uri->scheme && $uri->scheme =~ /^https?$/;
    return $FALSE if defined($uri->userinfo);
    return $FALSE unless ($uri->path // '') =~ m{^/admin(?:/|$)};
    my $host = lc($uri->host // '');
    return $FALSE if $host eq '';
    return (grep { $_ eq $host } allowed_callback_hosts()) ? $TRUE : $FALSE;
}

=head2 execute_actions

Register the device and apply the new node info

=cut

sub execute_actions {
    my ($self) = @_;
    my $access_level = $self->new_node_info->{access_level};
    if (!defined($access_level) || $access_level eq '' || $access_level eq 'NONE') {
        get_logger->warn("Admin SSO denied for " . ($self->username // 'unknown user') . ": no administration rule matched");
        return $FALSE;
    }
    my $rand = Bytes::Random::Secure->new(
            Bits        => 64,
            NonBlocking => 1,
        );
    my $token = unpack("H*", $rand->bytes(32));
    cache->set($token, $self->new_node_info);
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

