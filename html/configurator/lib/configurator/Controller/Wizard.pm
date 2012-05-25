package configurator::Controller::Wizard;

=head1 NAME

configurator::Controller::Wizard - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error is_success);
use JSON;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 SUBROUTINES

=over

=item index

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->redirect($c->uri_for($self->action_for('step1')));
}

=item object

Wizard controller dispatcher

=cut
sub object :Chained('/') :PathPart('wizard') :CaptureArgs(0) {
    my ( $self, $c ) = @_;

    $c->stash->{installation_type} = $c->model('Wizard')->checkForUpgrade();
}

=item step1

Enforcement mechanisms and network interfaces

=cut
sub step1 :Chained('object') :PathPart('step1') :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->request->method eq 'POST') {
        # Save parameters in user session
        my $data = decode_json($c->request->params->{json});
        $c->session(gateway => $data->{gateway},
                    types => $data->{types},
                    enforcements => {});
        map { $c->session->{enforcements}->{$_} = 1 } @{$data->{enforcements}};

        # Make sure all types for each enforcement is assigned to an interface
        # TODO: Shall we ignore disabled interfaces
        my @selected_types = values %{$data->{types}};
        my %seen;
        my @missing = ();
        @seen{@selected_types} = ( ); # build lookup table

        foreach my $enforcement (@{$data->{enforcements}}) {
            my $types_ref = $c->model('Enforcement')->getAvailableTypes($enforcement);
            foreach my $type (@{$types_ref}) {
                push(@missing, $type) unless exists $seen{$type};
            }
        }

        if (scalar @missing > 0) {
            $c->response->status($STATUS::PRECONDITION_FAILED);
            $c->stash->{status_msg} = $c->loc("You must assign an interface to the following types: [_1]", join(", ", @missing));
        }

        $c->stash->{current_view} = 'JSON';
    }
    else {
        $c->stash(interfaces => $c->model('Interface')->get('all'));
        $c->stash(types => $c->model('Enforcement')->getAvailableTypes(['inline', 'vlan']));
    }
}

=item step2

Database setup

=cut
sub step2 :Chained('object') :PathPart('step2') :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->request->method eq 'GET') {
        # Check if the database and user exist
        my ($status, $result_ref) = $c->model('Config::Pf')->read_value(
            ['database.user', 'database.pass', 'database.db']
        );
        if (is_success($status)) {
            $c->stash->{'db'} = $result_ref;
            # hash-slice assigning values to the list
            my ($pf_user, $pf_pass, $pf_db) = @{$result_ref}{qw/database.user database.pass database.db/};
            if ($pf_user && $pf_pass && $pf_db) {
                # throwing away result since we don't use it
                ($status) = $c->model('DB')->connect($pf_db, $pf_user, $pf_pass);
                $c->stash->{completed} = is_success($status);
            }
        }
    }
}

=item step3

PacketFence minimal configuration

=cut
sub step3 :Chained('object') :PathPart('step3') :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->request->method eq 'GET') {
        my ($status, $result_ref) = $c->model('Config::Pf')->read_value(
            ['general.domain', 'general.hostname', 'general.dhcpservers', 'alerting.emailaddr']
        );
        if (is_success($status)) {
            $c->stash->{'config'} = $result_ref;
        }
    }
    elsif ($c->request->method eq 'POST') {
        # Save parameters in user session
        $c->session(general => {domain => $c->request->params->{'general.domain'},
                                hostname => $c->request->params->{'general.hostname'},
                                dhcpservers => $c->request->params->{'general.dhcpservers'}},
                    alerting => {emailaddr => $c->request->params->{'alerting.emailaddr'}});
        $c->stash->{current_view} = 'JSON';
    }
}

=item step4

Administrator account

=cut
sub step4 :Chained('object') :PathPart('step4') :Args(0) {
    my ( $self, $c ) = @_;

    $c->stash->{completed} = defined($c->session->{admin_user});
}

=item step5

Confirmation and services launch

=cut
sub step5 :Chained('object') :PathPart('step5') :Args(0) {
    my ( $self, $c ) = @_;
}

=item reset_password

Reset the root password

=cut
sub reset_password :Path('reset_password') :Args(0) {
    my ( $self, $c ) = @_;

    my ($status, $message) = ( $STATUS::OK );
    my $root_user      = $c->request->params->{root_user};
    my $root_password  = $c->request->params->{root_password_new};

    unless ( $root_user && $root_password ) {
        ($status, $message) = ( $STATUS::BAD_REQUEST, 'Some required parameters are missing.' );
    }
    if ( is_success($status) ) {
        # ($status, $message) = $c->model('DB')->resetRootPassword($root_user, $root_password);
    }
    if ( is_error($status) ) {
        $c->response->status($status);
    }

    $c->stash->{status_msg} = $message;
    $c->stash->{current_view} = 'JSON';
}

=item create_admin

Create the administrative user

=cut
sub create_admin :Path('create_admin') :Args(0) {
    my ( $self, $c ) = @_;

    my ($status, $message) = ( $STATUS::OK );
    my $admin_user      = $c->request->params->{admin_user};
    my $admin_password  = $c->request->params->{admin_password};

    unless ( $admin_user && $admin_password ) {
        ($status, $message) = ( $STATUS::BAD_REQUEST, 'Some required parameters are missing.' );
    }
    if ( is_success($status) ) {
        ($status, $message) = $c->model('Wizard')->createAdminUser($admin_user, $admin_password);
    }
    if ( is_success($status) ) {
        $c->session('admin_user' => $admin_user);
    } else {
        $c->response->status($status);
    }

    $c->stash->{status_msg} = $message;
    $c->stash->{current_view} = 'JSON';
}

=back

=head1 AUTHORS

Derek Wuelfrath <dwuelfrath@inverse.ca>

Francis Lachapelle <flachapelle@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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
