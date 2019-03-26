package pfappserver::PacketFence::Controller::Config::Domain;

=head1 NAME

pfappserver::Controller::Configuration::Domain - Catalyst Controller

=head1 DESCRIPTION

Controller for Domain configuration.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pf::util;
use pf::domain;
use pf::config qw(%ConfigDomain %Config);

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object action from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'config/domain', CaptureArgs => 1 },
        # Configure access rights
        view            => { AdminRole => 'DOMAIN_READ' },
        list            => { AdminRole => 'DOMAIN_READ' },
        create          => { AdminRole => 'DOMAIN_CREATE' },
        clone           => { AdminRole => 'DOMAIN_CREATE' },
        update          => { AdminRole => 'DOMAIN_UPDATE' },
        update_rejoin   => { AdminRole => 'DOMAIN_UPDATE' },
        rejoin          => { AdminRole => 'DOMAIN_UPDATE' },
        remove          => { AdminRole => 'DOMAIN_DELETE' },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::Domain", form => "Config::Domain" },
    },
);

=head1 METHODS

=head2 before create clone update_rejoin

Set the bind_dn and the bind_pass as required

=cut

before [qw(create clone update_rejoin)] => sub {
    my ($self, $c) = @_;
    my $form = $self->getForm($c);
    for my $f (qw(bind_dn bind_pass)) {
        my $field = $form->field($f);
        $field->required(1);
    }
    $c->stash->{current_form_instance} = $form;
};

=head2 after create clone

Join the after creating or cloning domain

=cut

after [qw(create clone)] => sub {
    my ($self, $c) = @_;
    if( $c->request->method eq 'POST' && !$c->stash->{form}->has_errors ) {
        pf::domain::regenerate_configuration();
        my $output = pf::domain::join_domain($c->req->param('id'));
        $c->stash->{items}->{join_output} = $output;
        $c->forward('reset_credentials',[$c->req->param('id')]);
    }
};

before [qw(remove)] => sub{
    my ($self, $c) = @_;
    pf::domain::unjoin_domain($c->stash->{'id'});
};

after list => sub {
    my ($self, $c) = @_;
    $c->log->debug("Checking if user can edit the domain config");
    # we block the editing if the user has an OS configuration and no configured domains
    # this means he hasn't gone through the migration script
    $c->stash->{block_edit} = ( ( pf::domain::has_os_configuration() && !keys(%ConfigDomain) ) && isdisabled($Config{'advanced'}{'active_directory_os_join_check_bypass'}) );
};

=head2 after view

=cut

after view => sub {
    my ($self, $c) = @_;
    if (!$c->stash->{action_uri}) {
        my $id = $c->stash->{id};
        if ($id) {
            $c->stash->{action_uri} = $c->uri_for($self->action_for('update'), [$c->stash->{id}]);
        } else {
            $c->stash->{action_uri} = $c->uri_for($self->action_for('create'));
        }
    }
};

after list => sub {
    my ($self, $c) = @_;

    # now we add additionnal information in the hash

    foreach my $item (@{$c->stash->{items}}) {
      ( $item->{join_status}, $item->{join_output},
      ) = $c->model('Config::Domain')->status($item->{id});
    }

};

=head2 index

Usage: /config/domain/

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    $c->forward('list');
}

=head2 rejoin

Usage: /config/domain/rejoin/:domainId

=cut


sub rejoin :Local :Args(1) {
    my ($self, $c, $domain) = @_;
    my $info = pf::domain::rejoin_domain($domain);
    $c->forward('reset_credentials',[ $domain ]);
    $c->stash->{status_msg} = "Rejoined the domain";
    $c->stash->{items} = $info;
    $c->stash->{current_view} = 'JSON';
}

=head2 set_credentials

Usage: /config/domain/set_credentials/:domainId

=cut

sub set_credentials :Local :Args(1) {
    my ($self, $c, $domain) = @_;
    my $username = $c->request->param('username');
    my $password = $c->request->param('password');
    if ( (!defined $username) || length ($username) == 0 || (!defined $password) || length($password) == 0) {
        $c->stash(
            status_msg   => 'Username or Password not set',
            current_view => 'JSON',
        );
        $c->response->status(HTTP_BAD_REQUEST);
        return;
    }

    my $model = $self->getModel($c);
    my ($status,$result) = $model->update($domain, { bind_dn => $username, bind_pass => $password } );
    ($status,$result) = $model->commit();
    $c->stash(
        status_msg   => $result,
        current_view => 'JSON',
    );
    $c->response->status($status);

}

=head2 reset_credentials

Resets the password of the specified domain

=cut

sub reset_credentials :Private {
    my ($self, $c, $domain) = @_;
    my $model = $self->getModel($c);
    my ($status,$result) = $model->update($domain, { bind_dn => undef, bind_pass => undef } );
    ($status,$result) = $model->commit();
    $c->stash(
        status_msg   => $result,
        current_view => 'JSON',
    );
    $c->response->status($status);
}

=head2 update_rejoin

Usage: /config/domain/update_rejoin/:domainId

=cut


sub update_rejoin :Local :Args(1) {
    my ($self, $c, $domain) = @_;
    $c->stash->{id} = $domain;
    $c->forward('update');
    if (!$c->stash->{form}->has_errors) {
        $c->forward('rejoin');
    }
}

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
