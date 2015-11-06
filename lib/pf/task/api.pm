package pf::task::api;

=head1 NAME

pf::task::api

=cut

=head1 DESCRIPTION

pf::task::api

=cut

use strict;
use warnings;
use base 'pf::task';
use POSIX;
use pf::log;
use pf::api;
use pf::db;
use threads;
my $logger = get_logger();


=head2 doTask

Calls the api call

=cut

sub doTask {
    my ($self, $args) = @_;
    my ($method, @args) = @$args;
    if (pf::api->isPublic($method)) {
        my $pid;
        if (pf::api->shouldFork($method)) {
            pf::db::db_disconnect();
            $pid = fork;
            unless (defined $pid) {
                $logger->error("Error fork $!");
                return;
            }
            if ($pid) {
                $logger->debug("Fork $method off");
                return;
            }
        }
        eval {pf::api->$method(@args);};
        if ($@) {
            $logger->error($@);
        }
        if (defined $pid && $pid == 0 ) {
            POSIX::_exit(0);
        }
    } else {
        $logger->error("Invalid method '$method' given");
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;

