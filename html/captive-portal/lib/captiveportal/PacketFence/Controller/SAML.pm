package captiveportal::PacketFence::Controller::SAML;
use Moose;
use namespace::autoclean;
use File::Slurp qw(read_file);

BEGIN { extends 'captiveportal::Base::Controller'; }
use pf::config;

__PACKAGE__->config( namespace => 'saml', );

=head1 NAME

captiveportal::PacketFence::Controller::WirelessProfile - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub redirect :Local :Args(1) {
    my ($self, $c, $source_id) = @_;

    $c->forward('_validate_source', [$source_id]);
    
    my $source = $c->forward("_get_source", [$source_id]);

    $c->session(saml_source => $source_id);

    $c->response->redirect($source->sso_url);
}

sub assertion :Local {
    my ($self, $c) = @_;
    my $source_id = $c->session->{"saml_source"};

    unless($source_id){
        $self->showError($c, "Can't find associated SAML source in session.");
    }

    $c->forward('_validate_source', [$source_id]);

    my $source = $c->forward("_get_source", [$source_id]);

    my ($username, $msg) = $source->handle_response($c->request->param("SAMLResponse"));

    if($username){
        $c->session->{source_id} = $source_id;
        $c->session->{username} = $username;
        $c->forward( 'Authenticate' => 'postAuthentication');
        $c->forward( 'CaptivePortal' => 'webNodeRegister', [$c->stash->{info}->{pid}, %{$c->stash->{info}}] );
        $c->forward( 'CaptivePortal' => 'endPortalSession' );
    }
    else {
        $self->showError($c, $msg);
    }
}

sub _validate_source :Private {
    my ($self, $c, $source_id) = @_;
    unless($c->profile->hasSource($source_id)) {
        $self->showError($c, "Source $source_id is not allowed on the portal profile");
    }
}

sub _get_source :Private {
    my ($self, $c, $source_id) = @_;
    my $source = pf::authentication::getAuthenticationSource($source_id);

    unless($source){
        $self->showError("Can't find source $source_id");
    }
    return $source;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

