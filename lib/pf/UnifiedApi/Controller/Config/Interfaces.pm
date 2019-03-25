package pf::UnifiedApi::Controller::Config::Interfaces;

=head1 NAME

pf::UnifiedApi::Controller::Config::Interfaces -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Interfaces

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pfappserver::Model::Interface;
use pfappserver::Model::Enforcement;
use pfappserver::Form::Interface::Create;
use pf::UnifiedApi::Controller::Config;
use pf::error qw(is_success);

=head2 validate_item

Validate the parameters of an interface based on the context (create/update)

=cut

sub validate_item {
    my ($self, $form, $item) = @_;
    $form = $form->new(types => pfappserver::Model::Enforcement->new->getAvailableTypes("all"));

    $form->process(pf::UnifiedApi::Controller::Config::form_process_parameters_for_validation($self, $item));
    if (!$form->has_errors) {
        return $form->value;
    }

    $self->render_error(422, "Unable to validate", pf::UnifiedApi::Controller::Config::format_form_errors($self, $form));
    return undef;
}

=head2 model

Get the pfappserver model of the interfaces

=cut

sub model {
    my $model = pfappserver::Model::Interface->new;
    $model->ACCEPT_CONTEXT;
    return $model;
}

=head2 list

List all the interfaces

=cut

sub list {
    my ($self) = @_;
    my @items;
    my %interfaces = %{$self->model->get('all')};
    while(my ($id, $data) = each(%interfaces)) {
        $data->{id} = $id;
        push @items, $data;
    }

    $self->render(json => {items => [map { $self->normalize_interface($_) } @items]}, status => 200);
}

=head2 resource

Handler for resource

=cut

sub resource{1}

=head2 normalize_interface

Normalize interface information for JSON rendering

=cut

sub normalize_interface {
    my ($self, $interface) = @_;
    my @bools = qw(is_running network_iseditable);
    for my $bool (@bools) {
        $interface->{$bool} = $interface->{$bool} ? $self->json_true : $self->json_false;
     }
    return $interface;
}

=head2 get

Get a specific interface

=cut

sub get {
    my ($self) = @_;
    my $interface_id = $self->stash->{interface_id};
    my $interface = $self->model->get($interface_id);
    if(scalar(keys($interface)) > 0) {
        $interface = $interface->{$interface_id};
        $interface = $self->normalize_interface($interface);
        $self->render(json => {item => $interface}, status => 200);
    }
    else {
        $self->render_error(404, "Interface $interface_id doesn't exist");
    }
}

=head2 create

Create a new virtual interface

=cut
sub create {
    my ($self) = @_;
    my $data = $self->parse_json;
    $data = $self->validate_item("pfappserver::Form::Interface::Create", $data);
    my $full_name = $data->{name} . "." . $data->{vlan};
    my $model = $self->model;

    my ($status, $result) = $model->create($full_name);
    if (is_success($status)) {
        ($status, $result) = $model->update($full_name, $data);
    }
    $self->render(json => {result => pf::I18N::pfappserver->localize($result)}, status => $status);
}

=head2 update

Update an existing network interface

=cut

sub update {
    my ($self) = @_;
    my $data = $self->parse_json;
    $data = $self->validate_item("pfappserver::Form::Interface", $data);
    my $full_name = $self->stash->{interface_id};
    my $model = $self->model;

    my ($status, $result) = $model->update($full_name, $data);
    $self->render(json => {message => pf::I18N::pfappserver->localize($result)}, status => $status);
}

=head2 delete

Delete a virtual interface

=cut

sub delete {
    my ($self) = @_;
    my ($status, $result) = $self->model->delete($self->stash->{interface_id}, "");
    $status = is_success($status) ? 204 : $status;
    $self->render(json => {message => pf::I18N::pfappserver->localize($result)}, status => $status);
}

=head2 up

Put an interface up

=cut

sub up {
    my ($self) = @_;
    my ($status, $result) = $self->model->up($self->stash->{interface_id});
    $self->render(json => {message => pf::I18N::pfappserver->localize($result)}, status => $status);
}

=head2 down

Put an interface down

=cut

sub down {
    my ($self) = @_;
    my ($status, $result) = $self->model->down($self->stash->{interface_id});
    $self->render(json => {message => pf::I18N::pfappserver->localize($result)}, status => $status);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;
