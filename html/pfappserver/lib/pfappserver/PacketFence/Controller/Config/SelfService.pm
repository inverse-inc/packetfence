package pfappserver::PacketFence::Controller::Config::SelfService;

=head1 NAME

pfappserver::PacketFence::Controller::Config::SelfService add documentation

=cut

=head1 DESCRIPTION

ConnectionSelfService

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;
use pf::error;
use pf::config qw(%Profiles_Config);
use List::MoreUtils qw(any);

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object dispatcher from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'config/self_service', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'SELF_SERVICE_READ' },
        list   => { AdminRole => 'SELF_SERVICE_READ' },
        create => { AdminRole => 'SELF_SERVICE_CREATE' },
        clone  => { AdminRole => 'SELF_SERVICE_CREATE' },
        update => { AdminRole => 'SELF_SERVICE_UPDATE' },
        remove => { AdminRole => 'SELF_SERVICE_DELETE' },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::SelfService",form => "Config::SelfService" },
    },
);

=head1 METHODS

=head2 index

Usage: /config/provisioning

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;
    $c->forward('list');
}

before [qw(remove)] => sub {
    my ($self, $c, @args) = @_;
    # We check that it's not used by any connection profile
    my $count = 0;
    my $id = $c->stash->{'id'};
    while (my ($id, $config) = each %Profiles_Config) {
        $count ++ if ( any { $_ eq $c->stash->{'id'} } @{$config->{self_service}});
    }

    if ($count > 0) {
        $c->response->status($STATUS::FORBIDDEN);
        $c->stash->{status_msg} = "This self service policy is used by at least a Connection Profile.";
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }

};

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
