package pfappserver::PacketFence::Controller::Config::SwitchGroup;

=head1 NAME

pfappserver::PacketFence::Controller::Config::SwitchGroup - Catalyst Controller

=head1 DESCRIPTION

Controller for switch groups management.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pf::util qw(sort_ip isenabled);
use pf::SwitchFactory;

BEGIN {
    extends 'pfappserver::PacketFence::Controller::Config::Switch';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object dispatcher from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'config/switchgroup', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'SWITCHES_READ' },
        list   => { AdminRole => 'SWITCHES_READ' },
        create => { AdminRole => 'SWITCHES_CREATE' },
        clone  => { AdminRole => 'SWITCHES_CREATE' },
        update => { AdminRole => 'SWITCHES_UPDATE' },
        remove => { AdminRole => 'SWITCHES_DELETE' },
    },
);

=head2 begin

Setting the current form instance and model

=cut

sub begin :Private {
    my ($self, $c) = @_;
    my ($model, $status, $switch_default, $roles);

    $model = $c->model("Config::SwitchGroup");
    ($status, $switch_default) = $model->read('default');
    ($status, $roles) = $c->model('Config::Roles')->listFromDB;
    $roles = undef unless(is_success($status));
    $c->stash->{roles} = $roles;

    $c->stash->{current_model_instance} = $model;
    $c->stash->{switch_default} = $switch_default;

    $c->stash->{model_name} = "Switch Group";
    $c->stash->{controller_namespace} = "Config::SwitchGroup";
    $c->stash->{current_form_instance} = $c->form("Config::SwitchGroup", roles => $c->stash->{roles});
}

# Allows to reuse the switch templates by mapping the actions to the config/switch templates
after qw(view create clone update list index) => sub {
    my ($self, $c) = @_;
    my %map = (
        create => 'view',
        update => 'view',
        clone  => 'view',
    );
    my $action = $map{$c->action->name} || $c->action->name;
    $c->stash->{template} = 'config/switch/'.$action.".tt";
    $c->stash->{template} =~ s/switchgroup/switch/g;
};

# Allows to find the members and add them to the item
after qw(view update) => sub {
    my ($self, $c) = @_;

    my $cs = $c->model("Config::Switch")->configStore;
    my %members = map { $_->{id} => $_ } $cs->membersOfGroup($c->stash->{item}->{id});
    $c->stash->{item}->{members} = \%members;
    $c->stash->{tab} = $c->request->param("tab");
};

=head2 after_list

Override parent method to do the setup with the SwitchGroup model

=cut

sub after_list {
    my ($self, $c) = @_;
    $c->stash->{action} ||= 'list';
    $c->stash->{searchable} = 0;
};


1;
