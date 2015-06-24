package pfappserver::PacketFence::Controller::Config::Profile::BillingTier;

=head1 NAME

pfappserver::Controller::Configuration::Profile::BillingTier - Catalyst Controller

=head1 DESCRIPTION

Controller for Realm configuration.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pf::config::cached;

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}
use pfappserver::PacketFence::Controller::Config::Profile;

__PACKAGE__->config(
   action => {
       # Reconfigure the object action from pfappserver::Base::Controller::Crud
       # Configure access rights
       parent => { Chained => '/', PathPart => 'config/profile/billingtier', CaptureArgs => 1},
       object => { Chained => 'parent', CaptureArgs => 1 },
       list   => { AdminRole => 'USERS_SOURCES_READ', Args => 0, Chained => 'parent' },
       create => { AdminRole => 'USERS_SOURCES_CREATE', Args => 0, Chained => 'parent' },
       view   => { AdminRole => 'USERS_SOURCES_READ', },
       clone  => { AdminRole => 'USERS_SOURCES_CREATE' },
       update => { AdminRole => 'USERS_SOURCES_UPDATE' },
       remove => { AdminRole => 'USERS_SOURCES_DELETE' },
   },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::BillingTier", form => "Config::BillingTier" },
    },
);

sub parent :Chained('/') :PathPart('config/profile/billingtier')  :CaptureArgs(1)  {
    my ($self, $c, $source) = @_;
    my $old_model = $c->action->{model};
    $c->action->{model} = 'Config::Profile';
    pfappserver::PacketFence::Controller::Config::Profile::object($self, $c, $source);
    $c->action->{model} = $old_model;
};

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
