package pfappserver::Controller::Config::Networks;

=head1 NAME

pfappserver::Controller::Config::Networks - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;
use pfappserver::Form::Config::Network;
use pfappserver::Form::Config::Network::Routed;
use namespace::autoclean;

BEGIN {
    extends 'pfappserver::Base::Controller::Base';
    with 'pfappserver::Base::Controller::Crud::Config' => { -excludes => [ qw(getForm) ] };
}

=head1 METHODS

=head2 begin

Setting up the controllers model

=cut

sub begin :Private {
    my ( $self, $c ) = @_;
    pf::config::cached::ReloadConfigs();

    $c->stash(
        current_model_instance => $c->model("Config::Network")->new,
    );
}

=head2 getForm

Gettng the form for the current view

=cut

sub getForm {
    my ( $self, $c ) = @_;
    my $network = $c->stash->{network};
    my $network_ref = $c->stash->{item};
    my $form;
    if (!defined($network) || $network_ref->{next_hop}) {
        # Create or edit a routed network
        $form = pfappserver::Form::Config::Network::Routed->new(ctx => $c, network => $network);
    } else {
        # Edit the default interface network
        $form = pfappserver::Form::Config::Network->new(ctx => $c, network => $network);
    }
    return $form;
};


=head2 object

Chained dispatch

=cut

sub object :Chained('/') :PathPart('config/network') :CaptureArgs(1) {
    my ( $self, $c, $network ) = @_;
    $self->_setup_object($c, $network);
}

=head2 after create

=cut

after create => sub {
    my ($self, $c) = @_;
    if (!(is_success($c->response->status) && $c->request->method eq 'POST' )) {
        $c->stash->{template} = 'config/networks/view.tt';
    }
};

=head2 after view

=cut

after view => sub {
    my ($self, $c) = @_;
    if (!$c->stash->{action_uri}) {
        my $id = $c->stash->{network};
        if ($id) {
            $c->stash->{action_uri} = $c->uri_for($self->action_for('update'), [$c->stash->{network}]);
        } else {
            $c->stash->{action_uri} = $c->uri_for($self->action_for('create'));
        }
    }
};

=head1 COPYRIGHT

Copyright (C) 2012-2013 Inverse inc.

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
