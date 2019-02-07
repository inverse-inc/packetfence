package pfappserver::Model::Services;
use Moose;
use namespace::autoclean;

extends 'Catalyst::Model';

use pf::config;
use pf::file_paths qw($bin_dir);
use pf::error;
use pf::util;
use pf::services;
use pf::log;
use HTTP::Status qw(:constants :is);

=head1 NAME

pfappserver::Model::Services - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=over

=cut

our $PFCMD = File::Spec->catfile($bin_dir,'pfcmd');

=item _run_pfcmd

=cut

sub _run_pfcmd_service {
    my ($self,$service,$action) = @_;
    my $logger = get_logger();
    my $cmd = join(' ',$PFCMD,'service',( map { quotemeta } ($service,$action)),"2>&1");
    $logger->info("About to start the services with: $cmd");

    if(wantarray) {
        return (pf_run($cmd, ( 'accepted_exit_status' => [0 .. 255] ) ));
    }
    return scalar pf_run($cmd, ( 'accepted_exit_status' => [0 .. 255] ) );
}

=item start

Naively calls `bin/pfcmd service pf start` and return output.

=cut

sub start {
    my ($self) = @_;
    my $logger = get_logger();
    my $result = $self->_run_pfcmd_service("pf","start");
    $logger->debug("Startup output: " . $result);
    return ($STATUS::OK, {result => $result}) if ( defined($result) );

    return ($STATUS::INTERNAL_SERVER_ERROR, "Unidentified error see server side logs for details.");
}

=item stop_all

Naively calls `bin/pfcmd service pf restart` and return output.

=cut

sub stop_all {
    my ($self) = @_;
    return $self->service_cmd_background(qw(pf stop));
}

=item restart_all

Naively calls `bin/pfcmd service pf restart` and return output.

=cut

sub restart_all {
    my ($self) = @_;
    my $logger = get_logger();
    my $result = $self->_run_pfcmd_service("pf","restart");
    $logger->debug("Startup output: " . $result);
    return (HTTP_ACCEPTED, {result => $result}) if ( defined($result) );
    return ($STATUS::INTERNAL_SERVER_ERROR, "Unidentified error see server side logs for details.");
}

=item status

Calls and parse the output of `bin/pfcmd service pf status`.

Returns a tuple status, hashref with servicename => true / false values.
Returns only the list of services that should be started based on
configuration.

=cut

sub status {
    my ($self, $just_managed) = @_;
    my $logger = get_logger();
    my @services;
    foreach my $manager (grep { defined($_) && $_->name ne 'pf'} map {  pf::services::get_service_manager($_)  } @pf::services::ALL_SERVICES) {
        my $is_managed = $manager->isManaged();
        if ($just_managed && !$is_managed) {
            next;
        }
        my %info = (
            name   => $manager->name,
            status => $manager->status(1),
            is_managed => $is_managed,
        );
        if ($manager->isa("pf::services::manager::submanager")) {
            foreach my $submanager ($manager->managers) {
                push @{$info{managers}}, {name => $submanager->name, status => $submanager->status(1), is_managed => $is_managed};
            }
        }
        push @services, \%info;
    }

    return ($STATUS::OK, { services => \@services})
        if @services;

    return ($STATUS::INTERNAL_SERVER_ERROR, "Unidentified error see server side logs for details.");
}

=item server_status

Calls the webservices in order to get the server services status

Returns a tuple status, hashref with servicename => true / false values.
Returns only the list of services that should be started based on
configuration.

=cut

sub server_status {
    my ($self, $cluster_id) = @_;
    my $server_status;
    eval {
        ($server_status) = pf::cluster::call_server($cluster_id, 'services_status', [keys(%pf::services::ALL_MANAGERS)]);
    };
    unless($@) {
        my %services_ref = map { $_ => $server_status->{$_} ne '0' } keys %$server_status;
        return ($STATUS::OK, { services => \%services_ref}) if ( keys %services_ref );
    }

    my $msg = "Cannot get status from server $cluster_id : $@";
    get_logger->error($msg);
    return ($STATUS::INTERNAL_SERVER_ERROR, $msg);
}

=item service_status

=cut

sub service_status {
    my ($self,$service) = @_;
    my $sm = pf::services::get_service_manager($service);
    my %status = (
        pid => $sm->status,
        shouldBeStarted => $sm->isManaged
    );
    return ($STATUS::OK,\%status);
}

sub service_ctl {
    my ($self,$service,$verb) = @_;
    my $status = HTTP_OK;
    my $result = pf::services::service_ctl($service, $verb );
    unless (defined $result) {
        $status = HTTP_SERVICE_UNAVAILABLE;
        $result = ["unable to [_1] service [_2]",$verb,$service];
    }

    return ($status,{result => $result});
}




=item service_restart
=cut

sub service_restart {
    my ($self,$service) = @_;
    return $self->service_ctl($service,'restart');
}

=item service_stop
=cut

sub service_stop {
    my ($self,$service) = @_;
    return $self->service_ctl($service,'stop');
}


=item service_start
=cut

sub service_start {
    my ($self,$service) = @_;
    return $self->service_ctl($service,'start');
}


=item service_cmd

=cut

sub service_cmd {
    my ($self,@args) = @_;
    my $logger = get_logger();
    my $result = $self->_run_pfcmd_service(@args);
    $logger->debug("pfcmd service output: " . $result);
    return ($STATUS::OK, {result => $result}) if ( defined($result) );

    return ($STATUS::INTERNAL_SERVER_ERROR, "Unidentified error see server side logs for details.");
}

=item service_cmd_background

=cut

sub service_cmd_background {
    my ($self,$service,$action) = @_;
    my $logger = get_logger();
    my $cmd = join(' ','setsid',$PFCMD,'service',( map { quotemeta } ($service,$action))," &>/dev/null &");
    $logger->info("Defer the running of $cmd");
    $self->deferAction(
        sub {

            my $result = pf_run($cmd, ( 'accepted_exit_status' => [0 .. 255] ) );
            $logger->debug("Startup output: " . $result);
        }
    );
    return (HTTP_ACCEPTED, {});
}

sub deferAction {
    my ($self,@actions) = @_;
    if(defined $self->{_deferred_actions}) {
        push @{$self->{_deferred_actions}},@actions;
    }
}


sub ACCEPT_CONTEXT {
    my ($proto,$c,@args) = @_;
    my $object;
    if(ref($proto)) {
        $object = $proto;
    } else {
        $object = $proto->new;
    }
    #get the _actions_after_requests array if it is not already created
    if (exists $c->stash->{_deferred_actions}) {
        $object->{_deferred_actions} = $c->stash->{_deferred_actions};
    } else {
        $object->{_deferred_actions} = $c->stash->{_deferred_actions} = [];
    }
    return $object;
}

=back

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
