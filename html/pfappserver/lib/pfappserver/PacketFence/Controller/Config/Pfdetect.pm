package pfappserver::PacketFence::Controller::Config::Pfdetect;

=head1 NAME

pfappserver::Controller::Configuration::Pfdetect - Catalyst Controller

=head1 DESCRIPTION

Controller for Pfdetect configuration.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;
use pf::detect::parser::regex;
use pf::constants::pfdetect;
use pf::api;

pf::api::attributes::updateAllowedAsActions();


BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object action from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'config/pfdetect', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'PFDETECT_READ' },
        list   => { AdminRole => 'PFDETECT_READ' },
        create => { AdminRole => 'PFDETECT_CREATE' },
        clone  => { AdminRole => 'PFDETECT_CREATE' },
        update => { AdminRole => 'PFDETECT_UPDATE' },
        remove => { AdminRole => 'PFDETECT_DELETE' },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::Pfdetect", form => "Config::Pfdetect" },
    },
);

=head1 METHODS

=head2 after create clone

Show the 'view' template when creating or cloning pfdetect.

=cut

after [qw(create clone)] => sub {
    my ($self, $c) = @_;
    if (is_success($c->response->status) && $c->request->method eq 'POST') {
        my $model = $self->getModel($c);
        $c->response->location(
            $c->pf_hash_for(
                $c->controller('Config::Pfdetect')->action_for('view'),
                [$c->stash->{$model->idKey}]
            )
        );
    }
};

=head2 index

Usage: /config/pfdetect/

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{types} = [ @pf::constants::pfdetect::TYPES ],
    $c->forward('list');
}

=head2 before clone view _processCreatePost update

Update the form type

=cut

before [qw(clone view _processCreatePost update)] => sub {
    my ($self, $c, @args) = @_;
    my $model = $self->getModel($c);
    my $itemKey = $model->itemKey;
    my $item = $c->stash->{$itemKey};
    my $type = $item->{type};
    my $form = $c->action->{form};
    $c->stash->{current_form} = "${form}::${type}";
};


=head2 before - clone view update



=cut

before [qw(clone view update)] => sub {
    my ($self, $c) = @_;
    my @regex_allowed_actions;
    foreach my $method (sort keys %pf::api::attributes::ALLOWED_ACTIONS) {
        my $short_method_name = $method;
        $short_method_name =~ s/^pf::api:://;
        push @regex_allowed_actions, { method => $short_method_name, spec => $pf::api::attributes::ALLOWED_ACTIONS{$method} };
    }
    $c->stash->{'regex_allowed_actions'} = \@regex_allowed_actions;
};


=head2 create_type

Create sub type

=cut

sub create_type : Path('create') : Args(1) {
    my ($self, $c, $type) = @_;
    my $model = $self->getModel($c);
    my $itemKey = $model->itemKey;
    $c->stash->{$itemKey}{type} = $type;
    $c->forward('create');
}

=head2 test_regex_parser

=cut

sub test_regex_parser : Local {
    my ($self, $c) = @_;
    my ($status, $status_msg);
    my $form = $c->form("Config::Pfdetect::regex");
    $form->field('loglines')->is_active(1);
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $c->stash->{current_view} = 'JSON';
        $status                   = HTTP_BAD_REQUEST;
        $status_msg               = $form->field_errors;
        $c->response->status($status);
        $c->stash({
            current_view => 'JSON',
            status_msg   => $status_msg
        });
        return;
    }
    my $data     = $form->value;
    my $loglines = delete $data->{loglines} // '';
    my $parser   = pf::detect::parser::regex->new($data);
    my @lines = split(/\r\n/, $loglines);
    $c->stash->{dryrun_info} = $parser->dryRun(@lines);

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
