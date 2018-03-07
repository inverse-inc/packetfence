package captiveportal::PacketFence::DynamicRouting::Module::Authentication::SAML;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::SAML

=head1 DESCRIPTION

SAML authentication

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Authentication';
with 'captiveportal::Role::Routed';

use pf::util;
use pf::auth_log;
use pf::config::util;
use pf::constants::realm;

has '+source' => (isa => 'pf::Authentication::Source::SAMLSource');

has '+route_map' => (default => sub {
    tie my %map, 'Tie::IxHash', (
        '/saml/redirect' => \&redirect,
        '/saml/assertion' => \&assertion,
        # fallback to the index
        '/captive-portal' => \&index,
    );
    return \%map;
});

=head2 execute_child

Execute the module

=cut

sub execute_child {
    my ($self) = @_;
    $self->index();
}

=head2 index

SAML index

=cut

sub index {
    my ($self) = @_;
    $self->render("saml.html", {source => $self->source, title => "SAML authentication"});
}

=head2 redirect

Redirect the user to the SAML IDP

=cut

sub redirect {
    my ($self) = @_;
    pf::auth_log::record_oauth_attempt($self->source->id, $self->current_mac, $self->app->profile->name);
    $self->app->redirect($self->source->sso_url);
}

=head2 assertion

Handle the assertion that comes back from the IDP

=cut

sub assertion {
    my ($self) = @_;

    my ($username, $msg) = $self->source->handle_response($self->app->request->param("SAMLResponse"));

    # We strip the username if required
    ($username, undef) = pf::config::util::strip_username_if_needed($username, $pf::constants::realm::PORTAL_CONTEXT);

    if($username){
        pf::auth_log::record_completed_oauth($self->source->id, $self->current_mac, $username, $pf::auth_log::COMPLETED, $self->app->profile->name);
        $self->username($username);
        $self->done();
    }
    else {
        $self->app->error($msg);
        pf::auth_log::change_record_status($self->source->id, $self->current_mac, $pf::auth_log::FAILED, $self->app->profile->name);
    }
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

