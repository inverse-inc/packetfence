package pfappserver::PacketFence::Controller::Config::Fingerbank::DB;

=head1 NAME

pfappserver::PacketFence::Controller::Config::Fingerbank::DB

=head1 DESCRIPTION

Basic interaction with Fingerbank database.

Customizations can be made using L<pfappserver::Controller::Config::Fingerbank::DB>

=cut

use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;
use pf::constants;

BEGIN { extends 'pfappserver::Base::Controller'; }

=head2

Update "local" upstream Fingerbank database from Fingerbank project

=cut

sub update_upstream_db :Local :Args(0) :AdminRole('FINGERBANK_UPDATE') {
    my ( $self, $c ) = @_;

    $c->stash->{current_view} = 'JSON';

    my $apiclient = pf::client::getClient();
    $apiclient->notify('fingerbank_update_component', action => "update-upstream-db", email_admin => $TRUE);

    $c->stash->{status_msg} = $c->loc("Successfully dispatched update request for Fingerbank upstream DB. An email will follow for status");
}

=head2 submit

Allow submission of "unknown" and "unmatched" fingerprints to upstream Fingerbank project

=cut

sub submit :Local :Args(0) :AdminRole('FINGERBANK_READ') {
    my ( $self, $c ) = @_;

    $c->stash->{current_view} = 'JSON';

    my $apiclient = pf::client::getClient();
    $apiclient->notify('fingerbank_submit_unmatched');

    $c->stash->{status_msg} = $c->loc("Successfully dispatched submit request for unknown/unmatched fingerprints to Fingerbank. An email will follow for status");
}

=head2 update_p0f_map

Update the p0f map using the fingerbank library

=cut

sub update_p0f_map :Local :Args(0) :AdminRole('FINGERBANK_UPDATE') {
    my ( $self, $c ) = @_;

    $c->stash->{current_view} = 'JSON';

    my $apiclient = pf::client::getClient();
    $apiclient->notify('fingerbank_update_component', action => "update-p0f-map", email_admin => $TRUE);

    $c->stash->{status_msg} = $c->loc("Successfully dispatched update request for the p0f map. An email will follow for status");
}

=head2 update_redis_db

Update the redis db using the fingerbank library

=cut

sub update_redis_db :Local :Args(0) :AdminRole('FINGERBANK_UPDATE') {
    my ( $self, $c ) = @_;

    $c->stash->{current_view} = 'JSON';

    my $apiclient = pf::client::getClient();
    $apiclient->notify('fingerbank_update_component', action => "update-redis-db", email_admin => $TRUE);

    $c->stash->{status_msg} = $c->loc("Successfully dispatched update request for the redis DB. An email will follow for status");
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
