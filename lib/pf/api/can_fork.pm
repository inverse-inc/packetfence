package pf::api::can_fork;

=head1 NAME

pf::api::can_fork local client for pf::api

=cut

=head1 DESCRIPTION

pf::api::can_fork

can_fork client for pf::api which calls the api directly and fork on notify for api calls that are marked for forking
To avoid circular dependencies pf::api needs to be included before consuming this module

=cut

use strict;
use warnings;
use pf::log;
use pf::util::webapi;
use POSIX;
use Moo;

our $logger = get_logger();

=head2 call

calls the pf api

=cut

sub call {
    my ($self,$method,@args) = @_;
    pf::util::webapi::add_mac_to_log_context(\@args);
    return pf::api->$method(@args);
}

=head2 notify

calls the pf api ignoring the return value

=cut

sub notify {
    my ($self, $method, @args) = @_;
    my $pid;
    if (pf::api->shouldFork($method)) {
        $pid = fork;
        unless (defined $pid) {
            $logger->error("Error fork $!");
            return;
        }
        if ($pid) {
            $logger->debug("Fork $method off");
            return;
        }
        Log::Log4perl::MDC->put( 'tid', $$ );
    }
    pf::util::webapi::add_mac_to_log_context(\@args);
    eval {pf::api->$method(@args);};
    if ($@) {
        $logger->error("Error handling $method : $@");
    }
    if (defined $pid && $pid == 0 ) {
        POSIX::_exit(0);
    }
    return;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

