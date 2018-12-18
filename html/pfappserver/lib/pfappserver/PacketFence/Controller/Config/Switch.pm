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
        import => { AdminRole => 'SWITCHES_CREATE' },
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
    ($status, $roles) = $c->model('Config::Roles')->listFromDB;
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
    my $cs = $c->model('Config::Switch')->configStore;
    foreach my $switch (@{$c->stash->{items}}) {
        next if($switch->{id} =~ /^$groupPrefix /);
        my $id = $switch->{id};
        if ($id) {
            ($status, $floatingdevice) = $floatingDeviceModel->search('ip', $id);
            if (is_success($status)) {
                $switch->{floatingdevice} = pop @$floatingdevice;
            }
        }
        my $fullConfig = $cs->fullConfigRaw($id);
        $switch->{type} = $fullConfig->{type};
        $switch->{group} ||= $cs->topLevelGroup;
        $switch->{mode} = $fullConfig->{mode};
        $switch->{description} //= $fullConfig->{description};
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
    my $form = $c->form('AdvancedSearch');
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $status_msg = $form->field_errors;
        $c->stash(current_view => 'JSON', status_msg => $status_msg);
    } else {
        my $query = $form->value;
        $c->stash(current_view => 'JSON') if ($c->request->params->{'json'});
        ($status, $result) = $model->search($query);
        if (is_success($status)) {
            $c->stash(form => $form, action => 'search');
            $c->stash($result);
        }
    }
    $c->response->status($status);
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
    $c->stash->{import_form} = $c->form('Config::SwitchImport');
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

=head2 invalidate_cache

Usage /config/switch/:id/invalidate_cache

Invalidate switch distributed cache

=cut

sub invalidate_cache :Chained('object') :PathPart('invalidate_cache') :Args(0) {
    my ( $self, $c ) = @_;
    my $model = $self->getModel($c);
    my $idKey = $model->idKey;

    my $switch = pf::SwitchFactory->instantiate($c->stash->{$idKey});
    unless ( ref($switch) ) {
        $c->log->error("Unable to instantiate switch object using switch_id '" . $c->stash->{$idKey} . "'");
    }

    $switch->invalidate_distributed_cache();

    my $id = $c->stash->{$idKey};
    $c->stash(
        status_msg   => "Cleared distributed cache for switch ID '$id'",
        current_view => 'JSON',
    );
    $c->response->status(200);
}

=head1 import_csv

A method to be able to import switches from a CSV

=cut

sub import_csv :Local :Args(0) :AdminRole('SWITCHES_CREATE') {
    my ( $self, $c ) = @_;
   
    my $logger = pf::log->get_logger();
    my $upload = $c->req->upload('importcsv');
    my $file = $upload->fh;
    my $model = $c->model("Config::Switch");
    my $delimiter = $c->req->param('delimiter');
    my $model_group = $c->model("Config::SwitchGroup");

    # Map delimiter to its actual character
    if ($delimiter eq 'comma') {
        $delimiter = ',';
    } elsif ($delimiter eq 'semicolon') {
        $delimiter = ';';
    } elsif ($delimiter eq 'colon') {
        $delimiter = ':';
    } elsif ($delimiter eq 'tab') {
        $delimiter = "\t";
    }

    my $skip = 0;
    my $skip1 = 0;
    my $switches = 0;
    my %seen;
    my $csv = Text::CSV->new({ binary => 1, sep_char => $delimiter });
    my $line_count = 0;
    while (my $fields = $csv->getline($file)) {
        $line_count++;
        unless($skip1) {
            $skip1 = 1;
            next;
        }

        if (@$fields < 3) {
            $skip++;
            $logger->warn("This entry has been skipped because this line: $line_count contains more fields than required");
            next;
        }

        my $hostname = @$fields[0];
        $hostname =~ s/[^a-zA-Z0-9 _-]//g;
        $hostname =~ tr/\r\n//d;

        my $switch_ip = @$fields[1];
        # Don't want to process them twice...
        my ( $status, $msg ) = $model->hasId($switch_ip);
        if (is_success($status)) {
            $skip++;
            $logger->warn("This entry has been skipped because this IP: $switch_ip is existing in the switch configuration file.");
            next;
        }
    
        my $switch_group = @$fields[2];
        ( $status, $msg ) = $model_group->hasId($switch_group);
        if (is_error($status)) {
            $skip++;
            $logger->warn("This entry has been skipped because the switch group: $switch_group does not exist in the switch configutaion.");
            next;
        }

        my $assignements = {
            description => $hostname,
            group => $switch_group,
        };

        $model->create($switch_ip, $assignements);
        $switches++;
    }
    unless ($csv->eof) {
        $logger->warn("Problem with CSV file importation: " . $csv->error_diag());
        $c->stash( status_msg => $c->loc("Problem with importation: [_1]" , $csv->error_diag()));
    }
    $model->commit();
    $c->stash( status_msg => $c->loc("[_1] switches have been imported, [_2] switches have been skipped", $switches, $skip));
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
