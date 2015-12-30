package pfappserver::PacketFence::Controller::Config::Switch;

=head1 NAME

pfappserver::PacketFence::Controller::Config::Switch - Catalyst Controller

=head1 DESCRIPTION

Controller for switches management.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pf::util qw(sort_ip isenabled);
use pf::SwitchFactory;

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config' => { -excludes => [qw(list)] };
    with 'pfappserver::Base::Controller::Crud::Pagination';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object dispatcher from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'config/switch', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'SWITCHES_READ' },
        list   => { AdminRole => 'SWITCHES_READ' },
        create => { AdminRole => 'SWITCHES_CREATE' },
        clone  => { AdminRole => 'SWITCHES_CREATE' },
        update => { AdminRole => 'SWITCHES_UPDATE' },
        remove => { AdminRole => 'SWITCHES_DELETE' },
    },
    action_args => {
        search => { form => 'AdvancedSearch' },
    }
);

=head1 METHODS

=head2 begin

Setting the current form instance and model

=cut

sub begin :Private {
    my ($self, $c) = @_;
    my ($model, $status, $switch_default, $roles);

    $model = $c->model("Config::Switch");
    ($status, $switch_default) = $model->read('default');
    ($status, $roles) = $c->model('Roles')->list;
    $roles = undef unless(is_success($status));
    $c->stash->{roles} = $roles;

    $c->stash->{current_model_instance} = $model;
    $c->stash->{switch_default} = $switch_default;

    $c->stash->{model_name} = "Switch";
    $c->stash->{controller_namespace} = "Config::Switch";
    $c->stash->{current_form_instance} = $c->form("Config::Switch", roles => $c->stash->{roles});
}

after qw(list search) => sub {
    my ($self, $c) = @_;
    $self->after_list($c);
};

=head2 after_list

Check which switch is also defined as a floating device and sort switches by IP addresses.

=cut

sub after_list {
    my ($self, $c) = @_;
    $c->stash->{action} ||= 'list';

    my ($status, $floatingdevice, $ip);
    my @ips = ();
    my $floatingDeviceModel = $c->model('Config::FloatingDevice');
    my @switches;
    my $groupsModel = $c->model("Config::SwitchGroup");
    my $groupPrefix = $groupsModel->configStore->group;
    foreach my $switch (@{$c->stash->{items}}) {
        next if($switch->{id} =~ /^$groupPrefix /);
        my $id = $switch->{id};
        if ($id) {
            ($status, $floatingdevice) = $floatingDeviceModel->search('ip', $id);
            if (is_success($status)) {
                $switch->{floatingdevice} = pop @$floatingdevice;
            }
        }
        my $cs = $c->model('Config::Switch')->configStore;
        $switch->{type} = $cs->fullConfigRaw($id)->{type};
        $switch->{group} ||= $cs->topLevelGroup;
        $switch->{mode} = $cs->fullConfigRaw($id)->{mode};
        push @switches, $switch;
    }
    $c->stash->{switch_groups} = [ sort @{$groupsModel->readAllIds} ];
    unshift @{$c->stash->{switch_groups}}, $groupsModel->configStore->topLevelGroup;
    $c->stash->{items} = \@switches;
    $c->stash->{searchable} = 1;
}

=head2 search

/configuration/switch/search

Search the switch configuration entries

=cut

sub search : Local : AdminRole('SWITCHES_READ') {
    my ($self, $c) = @_;

    my $groupsModel = $c->model("Config::SwitchGroup");
    # Changing default to empty value as switches inheriting from it don't have a group attribute
    if($c->request->param("searches.0.value") eq $groupsModel->configStore->topLevelGroup){
        $c->request->param("searches.0.value", "");
    }

    my ($status, $status_msg, $result, $violations);
    my %search_results;
    my $model = $self->getModel($c);
    my $form = $self->getForm($c);
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $status_msg = $form->field_errors;
        $c->stash(current_view => 'JSON');
    } else {
        my $query = $form->value;
        $c->stash(current_view => 'JSON') if ($c->request->params->{'json'});
        ($status, $result) = $model->search($query);
        if (is_success($status)) {
            $c->stash(form => $form, action => 'search');
            $c->stash($result);
        }
    }
}

=head2 after create

=cut

after qw(create clone) => sub {
    my ($self, $c) = @_;
    if (!(is_success($c->response->status) && $c->request->method eq 'POST' )) {
        $c->stash->{template} = 'config/switch/view.tt';
        $c->stash->{action_uri} = $c->uri_for($self->action_for('create'));
    }
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

=head2 index

Usage: /config/switch/

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{action} = 'list';
    $c->forward('list');
}

=head2 remove_group

Usage /config/switch/:id/remove_group

Remove the group associated to a switch

=cut

sub remove_group :Chained('object') :PathPart('remove_group'): Args(0) {
    my ($self,$c) = @_;
    my $model = $self->getModel($c);
    my $idKey = $model->idKey;
    my $itemKey = $model->itemKey;
    my ($status,$result) = $self->getModel($c)->update($c->stash->{$idKey}, { group => undef });
    $self->getModel($c)->commit();
    $c->stash(
        status_msg   => $result,
        current_view => 'JSON',
    );
    $c->response->status($status);
}

=head2 add_to_group

Usage /config/switch/:id/add_to_group/:group_id

Add the switch to a group

=cut

sub add_to_group :Chained('object') :PathPart('add_to_group'): Args(1) {
    my ($self,$c,$group) = @_;
    my $model = $self->getModel($c);
    my $idKey = $model->idKey;
    my $itemKey = $model->itemKey;
    my ($status,$result) = $self->getModel($c)->update($c->stash->{$idKey}, { group => $group });
    $self->getModel($c)->commit();
    $c->stash(
        status_msg   => $result,
        current_view => 'JSON',
    );
    $c->response->status($status);
}

=head2 create_in_group

Usage /config/switch/create_in_group/:group_id

Create a switch directly in a group

=cut

sub create_in_group :Local :Args(1) :AdminRole('SWITCHES_CREATE') {
    my ($self, $c, $group) = @_;
    $c->forward('create');
    $c->stash->{item}->{group} = $group;
    $c->stash->{form}->field('group')->value($group);
    $c->stash->{form}->update_fields($c->stash->{item});
}

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
