package pfappserver::PacketFence::Controller::Config::Source;

=head1 NAME

pfappserver::PacketFence::Controller::Config::Source - Catalyst Controller

=head1 DESCRIPTION

Controller for authentication source

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pfappserver::Form::Config::Switch;
use pf::authentication;

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object action from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'config/source', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'USERS_SOURCES_READ' },
        list   => { AdminRole => 'USERS_SOURCES_READ' },
        create => { AdminRole => 'USERS_SOURCES_CREATE' },
        clone  => { AdminRole => 'USERS_SOURCES_CREATE' },
        update => { AdminRole => 'USERS_SOURCES_UPDATE' },
        remove => { AdminRole => 'USERS_SOURCES_DELETE' },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::Source", form => "Config::Source" },
    },
);

our @SOURCE_TYPES = qw(billing internal external exclusive);

=head1 METHODS

=head2 index

Usage: /config/source

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;
    my %types;
    foreach my $type (@SOURCE_TYPES) {
        $types{"${type}_types"} = availableAuthenticationSourceTypes($type);
    }
    $c->stash(\%types);
    $c->forward('list');
}

after list => sub {
    my ($self, $c) = @_;
    my $items = $c->stash->{items};
    my %source_by_class = map { $_ => [] } @SOURCE_TYPES;
    foreach my $item (@$items) {
        my $type = $item->{type};
        next if $type eq 'SQL';
        my $class = pf::authentication::getAuthenticationClassByType($type);
        $item->{class} = $class;
        push @{$source_by_class{$class}}, $item;
    }
    $c->stash({
        source_by_class => \%source_by_class,
    });
};

before [qw(clone view _processCreatePost update)] => sub {
    my ($self, $c, @args) = @_;
    my $model = $self->getModel($c);
    my $itemKey = $model->itemKey;
    my $item = $c->stash->{$itemKey};
    $self->setFormSubType($c, $item->{type});
};

before view => sub {
    my ($self, $c) = @_;
    my $message = delete $c->session->{message};
    if (defined $message) {
        $c->stash->{message} = $c->pf_localize($message);
    }
};

sub create_type : Path('create') : Args(1) {
    my ($self, $c, $type) = @_;
    my $model = $self->getModel($c);
    my $itemKey = $model->itemKey;
    $c->stash->{$itemKey}{type} = $type;
    $c->forward('create');
}

after [qw(create clone)] => sub {
    my ($self, $c) = @_;
    if ($c->request->method eq 'POST') {
        if(is_success($c->response->status)) {
            $c->session->{message} = $c->stash->{status_msg};
            $c->response->location( $c->pf_hash_for($self->action_for('view'), [$c->stash->{id}]));
        }
    }
};

sub setFormSubType {
    my ($self, $c, $type) = @_;
    my $form = $c->action->{form};
    $c->stash->{current_form} = "${form}::${type}";
    return;
}

=head2 test

Test the connection to a source of a specific type.

=cut

sub test :Local :Args(1) {
    my ($self, $c, $type) = @_;
    my ($status, $message) = (HTTP_METHOD_NOT_ALLOWED, 'The source cannot be tested.');
    $self->setFormSubType($c, $type);
    my $form = $self->getForm($c);
    $form->process(params => $c->request->params);
    eval {
        my $source = newAuthenticationSource($type, 'test', $form->getSourceArgs());
        if ($source && $source->can('test')) {
            ($status, $message) = $source->test();
            $status = $status ? HTTP_OK : HTTP_BAD_REQUEST;
        }
    };
    if ($@) {
        $c->log->debug($@);
        $status = HTTP_INTERNAL_SERVER_ERROR;
        $message = $c->loc("Unexpected error. See server-side logs for details.");
    }

    $c->response->status($status);
    $c->stash->{status_msg} = $message; # TODO: localize status message
    $c->stash->{current_view} = 'JSON';
}

=head2 saml_metadata

Generate the Service Provider metadata for a SAML source

=cut

sub saml_metadata :Local :Args(1) {
    my ($self, $c, $source_id) = @_;
    require 'pf::Authentication::Source::SAMLSource';

    $c->response->body(pf::authentication::getAuthenticationSource($source_id)->generate_sp_metadata());
    $c->response->content_type("text/xml");
}

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
