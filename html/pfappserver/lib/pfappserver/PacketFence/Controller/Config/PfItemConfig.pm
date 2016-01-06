package pfappserver::PacketFence::Controller::Config::PfItemConfig;

=head1 NAME

pfappserver::PacketFence::Controller::Config::PfItemConfig - Catalyst Controller

=head1 DESCRIPTION

Controller for admin roles management.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pfappserver::Form::Config::Switch;
use pf::config::cached;

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object action from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'config/pfitemconfig', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'PFITEMCONFIG_READ' },
        list   => { AdminRole => 'PFITEMCONFIG_READ' },
        create => { AdminRole => 'PFITEMCONFIG_CREATE' },
        clone  => { AdminRole => 'PFITEMCONFIG_CREATE' },
        update => { AdminRole => 'PFITEMCONFIG_UPDATE' },
        remove => { AdminRole => 'PFITEMCONFIG_DELETE' },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::PfItemConfig", form => "Config::PfItemConfig" },
    },
);

=head1 METHODS

=head2 index

Usage: /config/pfitemconfig

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;

    $c->forward('list');
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
