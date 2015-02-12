package pfappserver::Controller::Config::Fingerbank::Device;

=head1 NAME

pfappserver::Controller::Config::Fingerbank::Device - Catalyst Controller

=head1 DESCRIPTION

Controller for managing the fingerbank Device data

=cut

use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

BEGIN {
    extends 'pfappserver::Base::Controller';
    #Since we are creating our own index action to import it into our namespace
    with 'pfappserver::Base::Controller::Crud::Fingerbank' => { -exclude => 'index' };
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object and scope actions from
        __PACKAGE__->action_defaults,
        scope  => { Chained => '/', PathPart => 'config/fingerbank/device', CaptureArgs => 1 },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => __PACKAGE__->get_model_name , form => __PACKAGE__->get_form_name },
    },
);

=head2 index

Show the top level devices

=cut

sub index : Path :Args(0) {
    my ($self, $c) = @_;

    $self->children($c,undef);
}

=head2 children

Show child devices

=cut

sub children : Local : Args(1) {
    my ($self, $c, $parent_id) = @_;
    my $model = $self->getModel($c);
    my ($status, $devices) = $model->getSubDevices($parent_id);
    $c->stash->{items} = $devices;
}

=head1 COPYRIGHT

Copyright (C) 2015 Inverse inc.

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
