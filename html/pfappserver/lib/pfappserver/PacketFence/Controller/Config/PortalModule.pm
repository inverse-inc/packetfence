package pfappserver::PacketFence::Controller::Config::PortalModule;

=head1 NAME

pfappserver::Controller::Configuration::PortalModule - Catalyst Controller

=head1 DESCRIPTION

Controller for Portal modules configuration.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pf::constants;
use captiveportal::util;
use captiveportal::DynamicRouting::Factory;
use Tie::IxHash;
use List::MoreUtils qw(any);
use JSON::MaybeXS;
use pf::config qw(%ConfigPortalModules %Config);

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    namespace => 'config/portal_module',
    action => {
        # Reconfigure the object action from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'config/portal_module', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'PORTAL_MODULE_READ' },
        list   => { AdminRole => 'PORTAL_MODULE_READ' },
        create => { AdminRole => 'PORTAL_MODULE_CREATE' },
        clone  => { AdminRole => 'PORTAL_MODULE_CREATE' },
        update => { AdminRole => 'PORTAL_MODULE_UPDATE' },
        remove => { AdminRole => 'PORTAL_MODULE_DELETE' },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::PortalModule", form => "Config::PortalModule" },
    },
);

=head1 METHODS

=head2 after create clone

Show the 'view' template when creating or cloning a portal module.

=cut

after [qw(create clone)] => sub {
    my ($self, $c) = @_;
    if (!(is_success($c->response->status) && $c->request->method eq 'POST' )) {
        $c->stash->{template} = 'config/portal_module/view.tt';
    }
};

before [qw(clone view _processCreatePost update)] => sub {
    my ($self, $c, @args) = @_;
    my $model = $self->getModel($c);
    my $itemKey = $model->itemKey;
    my $item = $c->stash->{$itemKey};
    my $type = $item->{type};
    my $form = $c->action->{form};
    $c->stash->{current_form} = "${form}::${type}";
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

Usage: /config/portal_module/

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    $c->forward('list');
}

after list => sub {
    my ($self, $c) = @_;
    $c->stash->{items_by_type} = captiveportal::util::modules_by_type($c->stash->{items});

    tie my %types, 'Tie::IxHash', (map { $_ => [] } @{ordered_module_types()});
    my @skip = qw(TLSEnrollment Authentication Authentication::OAuth);
    foreach my $module (captiveportal::PacketFence::DynamicRouting::Factory->modules()){
        $module =~ s/^captiveportal::DynamicRouting::Module:://g;
        next if (any {$_ eq $module} @skip);

        if($module =~ /^(.+?)::(.+?)/){
            my $type = $1;
            $types{$type} //= [];
            push @{$types{$type}}, $module;
            next;
        }
        else {
            $types{$module} //= [];
        }
    }
    foreach my $type (keys %types){
        $types{$type} = [sort(@{$types{$type}})];
    }
    $c->stash->{types} = \%types;
};

after list => sub {
    my ($self, $c) = @_;
    my @roots = $self->getModel($c)->configStore->search("type", "Root", "id");
    my @structured_roots;
    foreach my $root (@roots){
        push @structured_roots, $self->_module_as_hashref($root->{id});
    }
    $c->stash->{structured_roots} = \@structured_roots;
    $c->stash->{structured_roots_json} = encode_json($c->stash->{structured_roots});
};

after view => sub {
    my ($self, $c) = @_;
    $c->stash->{node_roles} = $c->model('Config::Roles')->listFromDB();
    $c->stash->{access_durations} = [split(/\s*,\s*/, $Config{'guests_admin_registration'}{'access_duration_choices'})];
    $c->stash->{root_modules} = [map { $_->{id} } $self->getModel($c)->configStore->search("type", "Root", "id")];
};

sub _module_as_hashref : Private {
    my ($self, $id) = @_;
    my $modules = $ConfigPortalModules{$id}{modules};
    return {
        label => "$id (".$ConfigPortalModules{$id}{description}.")",
        id => $id,
        children => [map { $self->_module_as_hashref($_) } @$modules],
    };
}


sub create_type : Path('create') : Args(1) {
    my ($self, $c, $type) = @_;
    my $form = $c->action->{form};

    $c->stash->{current_form} = "${form}::${type}";

    my $model = $self->getModel($c);
    my $itemKey = $model->itemKey;
    $c->stash->{$itemKey}{type} = $type;
    $c->forward('create');
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
