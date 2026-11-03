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
use pf::api::can_fork;
my $logger = get_logger();

=head2 %DENIED_METHODS

Api methods that are never run from the queue

=cut

our %DENIED_METHODS = map { $_ => 1 } qw(
    copy_directory
    distant_download_configfile
    download_configfile
    expire_cluster
    notify_configfile_changed
    queue_job
    sync_config_as_master
);

=head2 isAllowedMethod

Check if an api method can be run from the queue

=cut

sub isAllowedMethod {
    my ($self, $method) = @_;
    return 0 if !defined($method) || ref($method) || $DENIED_METHODS{$method};
    return pf::api->isQueue($method) ? 1 : 0;
}

=head2 doTask

Calls the api call

=cut

sub doTask {
    my ($self, $args) = @_;
    my $method = ref($args) eq 'ARRAY' ? $args->[0] : undef;
    unless ($self->isAllowedMethod($method)) {
        $logger->error("Refusing api task " . ($method // ''));
        return ({ message => "Api method not allowed", status => 403 }, undef);
    }

    my $api_client = pf::api::can_fork->new();
    $logger->info("Calling api task $method");
    $api_client->notify(@$args);
    return (undef, undef);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

