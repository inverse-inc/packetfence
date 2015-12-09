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

after qw(begin) => sub {
    my ($self, $c) = @_;
    $c->stash->{model_name} = "Switch Group";
    $c->stash->{controller_namespace} = "Config::SwitchGroup";
    $c->stash->{current_form_instance} = $c->form("Config::SwitchGroup", roles => $c->stash->{roles});
};

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

after qw(view update) => sub {
    my ($self, $c) = @_;
    use Data::Dumper;
    my $cs = $c->model("Config::Switch")->configStore;
    my %members = map { $_->{id} => $_ } $cs->search("group", $c->stash->{item}->{id}, "id");
    $c->stash->{item}->{members} = \%members;
};

sub after_list {
    my ($self, $c) = @_;
    $c->stash->{action} ||= 'list';

    my @switches;
    foreach my $switch (@{$c->stash->{items}}) {
        my $id = $switch->{id};
        next unless(isenabled($switch->{is_group}));
        my $cs = $c->model('Config::Switch')->configStore;
        $switch->{type} = $cs->full_config_raw($id)->{type}; 
        $switch->{mode} = $cs->full_config_raw($id)->{mode}; 
        push @switches, $switch;
    }
    $c->stash->{items} = \@switches; 
    $c->stash->{searchable} = 0;
};


1;
