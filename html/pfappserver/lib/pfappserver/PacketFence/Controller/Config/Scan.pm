package pfappserver::PacketFence::Controller::Config::Scan;

=head1 NAME

pfappserver::PacketFence::Controller::Config::Scan - Catalyst Controller

=head1 DESCRIPTION

Controller for scan management.

=cut

use HTTP::Status qw(:constants is_error is_success);
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;
use List::MoreUtils qw(any);
use pf::config qw(%Profiles_Config);

use pf::factory::scan;

BEGIN {
    extends 'pfappserver::Base::Controller';
    with 'pfappserver::Base::Controller::Crud::Config';
    with 'pfappserver::Base::Controller::Crud::Config::Clone';
}

__PACKAGE__->config(
    action => {
        # Reconfigure the object action from pfappserver::Base::Controller::Crud
        object => { Chained => '/', PathPart => 'config/scan', CaptureArgs => 1 },
        # Configure access rights
        view   => { AdminRole => 'SCAN_READ' },
        list   => { AdminRole => 'SCAN_READ' },
        create => { AdminRole => 'SCAN_CREATE' },
        clone  => { AdminRole => 'SCAN_CREATE' },
        update => { AdminRole => 'SCAN_UPDATE' },
        remove => { AdminRole => 'SCAN_DELETE' },
    },
    action_args => {
        # Setting the global model and form for all actions
        '*' => { model => "Config::Scan", form => "Config::Scan" },
    },
);

=head1 METHODS

=head2 after create clone

Show the 'view' template when creating or cloning a scan engine.

=cut

before [qw(clone view _processCreatePost update)] => sub {
    my ($self, $c, @args) = @_;
    my $model = $self->getModel($c);
    my $itemKey = $model->itemKey;
    my $item = $c->stash->{$itemKey};
    my $type = $item->{type};
    my $form = $c->action->{form};
    $c->stash->{current_form} = "${form}::${type}";
};

sub create_type : Path('create') : Args(1) {
    my ($self, $c, $type) = @_;
    my $model = $self->getModel($c);
    my $itemKey = $model->itemKey;
    $c->stash->{$itemKey}{type} = $type;
    $c->forward('create');
}

=head2 index

Usage: /config/scan/

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{types} = [ sort grep {$_} map { /^pf::scan::(.*)/;$1  } @pf::factory::scan::MODULES];
    $c->forward('list');
}

before [qw(remove)] => sub {
    my ($self, $c, @args) = @_;
    # We check that it's not used by any connection profile
    my $found = 0;
    my $id = $c->stash->{item}{id};
    for my $config (values %Profiles_Config) {
        my @scans = split( /\s*,\s*/, ($config->{scans} // ''));
        if ( any { $_ eq $id } @scans ) {
            $found = 1;
            last;
        }
    }

    if ($found) {
        $c->response->status($STATUS::FORBIDDEN);
        $c->stash->{status_msg} = "This scanner is used by at least one Connection Profile.";
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
