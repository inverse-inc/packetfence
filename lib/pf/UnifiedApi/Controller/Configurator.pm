package pf::UnifiedApi::Controller::Configurator;

=head1 NAME

pf::UnifiedApi::Controller::Configurator -

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Configurator

=cut

use strict;
use warnings;
use Mojo::UserAgent;
use Mojo::Transaction::HTTP;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::config qw(%Config $management_network);
use pf::ConfigStore::Pf;
use pf::services;
use pf::util;
use pf::constants;
use pf::api::unifiedapiclient;


sub allowed {
    my ($self) = @_;
    if (isenabled($Config{advanced}{configurator})) {
        return $TRUE;
    }
    return $self->render_error(401, "The configurator is turned off");
}

sub complete {
    my ($self) = @_;
    my $result = eval { $self->do_complete() };
    if (my $error = $@) {
        return $self->render_error(500, "$error");
    }
    return $self->render(json => $result);
}

sub do_complete {
    my ($self) = @_;
    die "A management interface must be configured before completing setup\n"
        unless ref($management_network) && $management_network->tag('ip');

    my @services = grep { $_ ne 'pf' } @pf::services::ALL_SERVICES;
    my @stopped = map { $_->name }
        grep { $_->isManaged && !$_->optional && !$_->isAlive }
        pf::services::getManagers(\@services);
    die "Services must be running before completing setup: " . join(', ', @stopped) . "\n"
        if @stopped;

    my $cs = pf::ConfigStore::Pf->new;
    my $advanced = $cs->read('advanced');
    die "The configurator is turned off\n"
        unless $advanced && isenabled($advanced->{configurator});
    my $previous = $advanced->{configurator};
    my $completed = eval {
        $self->_save_configurator($cs, 'disabled');
        # The worker's cached configuration can still contain the old setting.
        # Only this completion operation may bypass it, after the save succeeds.
        pf::services::promote_default_systemd_target(configurator_finishing => 1);
        1;
    };
    unless ($completed) {
        my $error = $@;
        # A failed commit may already have written pf.conf. Restore the setting
        # on either save or promotion failure so the wizard remains retryable.
        eval { $self->_save_configurator(pf::ConfigStore::Pf->new, $previous) };
        $error .= "Unable to restore the configurator: $@" if $@;
        die $error;
    }
    return { message => 'Configuration completed' };
}

sub _save_configurator {
    my ($self, $cs, $value) = @_;
    die "Unable to update the configurator setting\n"
        unless $cs->update('advanced', { configurator => $value });
    my ($saved, $error) = $cs->commit();
    die "Unable to save the configurator setting: " . ($error // 'unknown error') . "\n"
        unless $saved;
    if ($ENV{PF_UID} && $ENV{PF_GID}) {
        chown($ENV{PF_UID}, $ENV{PF_GID}, $cs->configFile);
    }
}

sub proxy_api_frontend {
    my ($self) = @_;
    my $req = $self->req->clone;
    my $url = $req->url;
    $url->scheme("https")->port(9999)->host('localhost');
    my $path = $url->path;
    $path =~ s#/api/v1/configurator/#/api/v1/#;
    $url->path($path);
    add_token($req);
    my $ua = Mojo::UserAgent->new;
    $ua->insecure(1);
    my $tx = $ua->start(Mojo::Transaction::HTTP->new(req => $req));
    return _proxy_tx($self, $tx);
}

sub add_token {
    my ($req) = @_;
    my $headers = $req->headers;
    if ($headers->authorization) {
        return;
    }

    my $default_client = pf::api::unifiedapiclient->default_client;
    my $token = $default_client->token;
    if (!$token) {
        $default_client->login();
        $token = $default_client->token;
    }
    if ($token) {
        $headers->authorization("Bearer $token");
    }
}

sub _proxy_tx {
    my ( $self, $tx ) = @_;
    my $error = $tx->error;
    if ( !$error || $error->{code} ) {
        my $res = $tx->res;
        $self->tx->res($res);
        $self->rendered;
    }
    else {
        $self->tx->res->headers->add( 'X-Remote-Status',
            ( $error->{status} // 500 ) . ': ' . $error->{message} );
        $self->render( status => 500, json => $error );
    }
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

