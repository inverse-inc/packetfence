package pfappserver::Controller::Config::Domain;

=head1 NAME

pfappserver::Controller::Configuration::Domain - Catalyst Controller

=head1 DESCRIPTION

Controller for Domain configuration.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pf::config::cached;
use pf::util;
use pf::domain;

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
        refresh_domains => { AdminRole => 'DOMAIN_UPDATE' },
        rejoin          => { AdminRole => 'DOMAIN_UPDATE' },
        remove          => { AdminRole => 'DOMAIN_DELETE' },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::Domain", form => "Config::Domain" },
    },
);

=head1 METHODS

=head2 after create clone

Show the 'view' template when creating or cloning domain.

=cut

after [qw(create clone)] => sub {
    my ($self, $c) = @_;
    if (!(is_success($c->response->status) && $c->request->method eq 'POST' )) {
        $c->stash->{template} = 'config/domain/view.tt';
    }
};

after [qw(create update)] => sub {
    my ($self, $c) = @_;
    if($c->request->method eq 'POST' ){
        pf::domain::regenerate_configuration();
        pf::domain::join_domain($c->req->param('id'));
    }
};

before [qw(remove)] => sub{
    my ($self, $c) = @_;
    pf::domain::unjoin_domain($c->stash->{'id'});
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
      ($item->{winbind_status}, $item->{winbind_output}, $item->{ntlm_auth_status}, $item->{ntlm_auth_output}) = $c->model('Config::Domain')->status($item->{id});
    }

};

=head2 index

Usage: /config/domain/

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    $c->forward('list');
}

=head2 refresh_domains

Usage: /config/domain/refresh_domains

=cut

sub refresh_domains :Local {
    my ($self, $c) = @_;
    pf::domain::regenerate_configuration();
    $c->stash->{status_msg} = "Refreshed the domains";
    $c->stash->{current_view} = 'JSON';
}

=head2 rejoin

Usage: /config/domain/rejoin/:domainId

=cut


sub rejoin :Local :Args(1) {
    my ($self, $c, $domain) = @_;
    pf::domain::rejoin_domain($domain);
    $c->stash->{status_msg} = "Rejoined the domain";
    $c->stash->{current_view} = 'JSON';
}

=head1 COPYRIGHT

Copyright (C) 2014 Inverse inc.

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
