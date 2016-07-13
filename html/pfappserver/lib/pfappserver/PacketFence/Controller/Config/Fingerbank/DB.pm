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
use pf::util;
use pf::config::util;
use pf::error qw(is_success);

BEGIN { extends 'pfappserver::Base::Controller'; }

=head2 update_upstream_db

Update "local" upstream Fingerbank database from Fingerbank project

=cut

sub update_upstream_db :Local :Args(0) :AdminRole('FINGERBANK_UPDATE') {
    my ( $self, $c ) = @_;

    $c->stash->{current_view} = 'JSON';

    pf::cluster::notify_each_server('fingerbank_update_component', action => "update-upstream-db", email_admin => $TRUE, fork_to_queue => $TRUE);

    $c->stash->{status_msg} = $c->loc("Successfully dispatched update request for Fingerbank upstream DB. An email will follow for status");
}

=head2 submit

Allow submission of "unknown" and "unmatched" fingerprints to upstream Fingerbank project

=cut

sub submit :Local :Args(0) :AdminRole('FINGERBANK_READ') {
    my ( $self, $c ) = @_;

    $c->stash->{current_view} = 'JSON';

    pf::cluster::notify_each_server('fingerbank_submit_unmatched');

    $c->stash->{status_msg} = $c->loc("Successfully dispatched submit request for unknown/unmatched fingerprints to Fingerbank. An email will follow for status");
}

=head2 update_p0f_map

Update the p0f map using the fingerbank library

=cut

sub update_p0f_map :Local :Args(0) :AdminRole('FINGERBANK_UPDATE') {
    my ( $self, $c ) = @_;

    $c->stash->{current_view} = 'JSON';

    pf::cluster::notify_each_server('fingerbank_update_component', action => "update-p0f-map", email_admin => $TRUE);

    $c->stash->{status_msg} = $c->loc("Successfully dispatched update request for the p0f map. An email will follow for status");
}

=head2 update_redis_db

Update the redis db using the fingerbank library

=cut

sub update_redis_db :Local :Args(0) :AdminRole('FINGERBANK_UPDATE') {
    my ( $self, $c ) = @_;

    $c->stash->{current_view} = 'JSON';

    pf::cluster::notify_each_server('fingerbank_update_component', action => "update-redis-db", email_admin => $TRUE, fork_to_queue => $TRUE);

    $c->stash->{status_msg} = $c->loc("Successfully dispatched update request for the redis DB. An email will follow for status");
}

=head2 initialize_mysql

Initialize the MySQL database

=cut

sub initialize_mysql :Local :AdminRole('FINGERBANK_UPDATE') :AdminConfigurator {
    my ( $self, $c ) = @_;
    # HACK alert !
    # Need to launch this job through an async bash session since this can be executed in the context of the configurator which means our Apache process can be restarted at any time.
    my $pid = fork();
    if($pid) {
        $c->session->{importing_fingerbank_mysql} = $TRUE;
        $c->stash->{current_view} = 'JSON';
        $c->stash->{status_msg} = $c->loc("Dispatched the import job to PID $pid. An e-mail will follow up for status.");
    }
    else {
        close STDERR;
        close STDIN;
        close STDOUT;

        use POSIX();
        POSIX::setsid();
        # MASSIVE HACK alert ! : we do the import through a bash script async but system will not return before this has ended...
        # So, we put an alarm in 10 seconds to give time to the script to start and then we die
        # If we don't, then this process will keep the bind on 1443 and prevent any httpd.admin restart
        alarm 10;
        `bash -c "/usr/local/pf/bin/mysql_fingerbank_import.sh &"`;
    }
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
