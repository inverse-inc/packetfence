package pfappserver::Model::Services;
use Moose;
use namespace::autoclean;

extends 'Catalyst::Model';

use pf::config;
use pf::error;
use pf::util;
use pf::services;

=head1 NAME

pfappserver::Model::Services - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=over

=item start

Naively calls `bin/pfcmd service pf start` and return output.

=cut
sub start {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $cmd = $bin_dir . '/pfcmd service pf start 2>&1';
    $logger->info("About to start the services with: $cmd");

    my $result = pf_run($cmd, ( 'accepted_exit_status' => [0 .. 255] ) );
    $logger->debug("Startup output: " . $result);

    return ($STATUS::OK, {result => $result}) if ( defined($result) );

    return ($STATUS::INTERNAL_SERVER_ERROR, "Unidentified error see server side logs for details.");
}

=item stop_all

Naively calls `bin/pfcmd service pf restart` and return output.

=cut
sub stop_all {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $cmd = $bin_dir . '/pfcmd service pf stop 2>&1';
    $logger->info("About to start the services with: $cmd");

    my $result = pf_run($cmd, ( 'accepted_exit_status' => [0 .. 255] ) );
    $logger->debug("Startup output: " . $result);

    return ($STATUS::OK, {result => $result}) if ( defined($result) );

    return ($STATUS::INTERNAL_SERVER_ERROR, "Unidentified error see server side logs for details.");
}

=item restart_all

Naively calls `bin/pfcmd service pf restart` and return output.

=cut
sub restart_all {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $cmd = $bin_dir . '/pfcmd service pf restart 2>&1';
    $logger->info("About to start the services with: $cmd");

    my $result = pf_run($cmd, ( 'accepted_exit_status' => [0 .. 255] ) );
    $logger->debug("Startup output: " . $result);

    return ($STATUS::OK, {result => $result}) if ( defined($result) );

    return ($STATUS::INTERNAL_SERVER_ERROR, "Unidentified error see server side logs for details.");
}

=item status

Calls and parse the output of `bin/pfcmd service pf status`.

Returns a tuple status, hashref with servicename => true / false values.
Returns only the list of services that should be started based on
configuration.

=cut
sub status {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $cmd = $bin_dir . '/pfcmd service pf status 2>&1';
    $logger->info("Requesting services status with: $cmd");

    my @services_status = pf_run( $cmd, ( 'accepted_exit_status' => [0 .. 255] ) );
    $logger->debug(
        "Service status output: "
        . ( (@services_status) ? join('', @services_status) : 'NONE' )
    );

    # TODO extract service\|shouldBeStarted\|pid into constant and use constant both here and when we report on CLI
    if (!@services_status || $services_status[0] !~ /^service\|shouldBeStarted\|pid$/) {
        return ( $STATUS::INTERNAL_SERVER_ERROR, join('', @services_status) );
    }

    my $services_ref = {};
    shift @services_status; # throw out first line
    foreach my $service_status (@services_status) {
        chomp($service_status);
        my ($service_name, $should_be_started, $pids) = split(/\|/, $service_status);
        $services_ref->{$service_name} = ($pids) if ($should_be_started);
    }
    return ($STATUS::OK, { services => $services_ref}) if ( %$services_ref );

    return ($STATUS::INTERNAL_SERVER_ERROR, "Unidentified error see server side logs for details.");
}

=item service_status


=cut

sub service_status {
    my ($self,$service) = @_;
    my @services = @pf::services::ALL_SERVICES;
    my @services_which_should_be_started = pf::services::service_list(@services);
    my %status = (
        pid => pf::services::service_ctl($service, 'status' ),
        shouldBeStarted => (
                (   grep( { $_ eq $service } @services_which_should_be_started )
                        > 0
                ) ? 1 : 0
            )
    );
    return ($STATUS::OK,\%status);
}

sub _service_ctl {
    my ($self,$service,$verb) = @_;
    my $status = $STATUS::OK;
    my $result = pf::services::service_ctl($service, $verb );
    if($result) {
        $result = {};
    } else {
        $status = $STATUS::SERVICE_UNAVAILABLE;
        $result = "unable to $verb service $service";
    }

    return ($status,$result);
}

=item service_restart
=cut

sub service_restart {
    my ($self,$service) = @_;
    return $self->_service_ctl($service,'restart');
}

=item service_stop
=cut

sub service_stop {
    my ($self,$service) = @_;
    return $self->_service_ctl($service,'stop');
}


=item service_start
=cut

sub service_start {
    my ($self,$service) = @_;
    return $self->_service_ctl($service,'start');
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012-2013 Inverse inc.

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
