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
use Data::Dumper;

sub model {
    my $model = pfappserver::Model::Interface->new;
    $model->ACCEPT_CONTEXT;
    return $model;
}

sub list {
    my ($self) = @_;
    $self->render(json => {items => [$self->model->_listInterfaces('all')]}, status => 200);
}

sub resource{
    my ($self) = @_;
    #return $self->get();
}

sub get {
    my ($self) = @_;
    my $interface_id = $self->stash->{interface_id};
    my $interface = $self->model->get($interface_id);
    if(scalar(keys($interface)) > 0) {
        $interface = $interface->{$interface_id};
        $interface->{is_running} = $interface->{is_running} ? $self->json_true : $self->json_false;
        $self->render(json => $interface, status => 200);
    }
    else {
        $self->render_error(404, {message => "Interface $interface_id doesn't exist"});
    }
}

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

sub update {
    my ($self) = @_;
    my $data = $self->parse_json;
    $data = $self->validate_item("pfappserver::Form::Interface", $data);
    my $full_name = $self->stash->{interface_id};
    my $model = $self->model;

    my ($status, $result) = $model->update($full_name, $data);
    $self->render(json => {message => pf::I18N::pfappserver->localize($result)}, status => $status);
}

sub delete {
    my ($self) = @_;
    my ($status, $result) = $self->model->delete($self->stash->{interface_id}, "");
    $self->render(json => {message => pf::I18N::pfappserver->localize($result)}, status => $status);
}

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
