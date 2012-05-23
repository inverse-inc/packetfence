package configurator::Controller::Wizard;

=head1 NAME

configurator::Controller::Wizard - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=cut

use strict;
use warnings;

use HTTP::Status qw(:constants is_error);
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
        $c->stash->{current_view} = 'JSON';
    }
    else {
        $c->stash(interfaces => $c->model('Interface')->get('all'));
    }
}

=item step2

Database setup

=cut
sub step2 :Chained('object') :PathPart('step2') :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->request->method eq 'POST') {
        # Save parameters in user session
        $c->session(root_user => $c->request->params->{root_user},
                    pf_user => $c->request->params->{pf_user},
                    database => $c->request->params->{database});
        $c->stash->{current_view} = 'JSON';
    }

    # Check if the database user exists
    my ($pf_user, $pf_pass);

    my ($status, $result) = $c->model('Config::Pf')->read('database.user');
    if ( !is_error($status) ) {
        $pf_user = $result->[0]->{value};
        ($status, $result) = $c->model('Config::Pf')->read('database.pass');
        if ( !is_error($status) ) {
            $pf_pass = $result->[0]->{value};
        }
        if ($pf_user && $pf_pass) {
            ($status, $result) = $c->model('DB')->connect('mysql', $pf_user, $pf_pass);
            $c->stash->{userExists} = !is_error($status);
        }
    }
    else {
        $c->log->error($result);
    }

    # Check if the database exists
}

=item step3

PacketFence minimal configuration

=cut
sub step3 :Chained('object') :PathPart('step3') :Args(0) {
    my ( $self, $c ) = @_;

    if ($c->request->method eq 'POST') {
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


}

=item step5

Confirmation and services launch

=cut
sub step5 :Chained('object') :PathPart('step5') :Args(0) {
    my ( $self, $c ) = @_;
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
