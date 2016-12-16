package pf::services::manager;
=head1 NAME

pf::services::manager

=cut

=head1 DESCRIPTION

pf::services::manager

This module encapsulates the service actions/commands for pfcmd tool

=head1 EXAMPLES

An example of a new service foo

    package pf::services::manager::moo;

    use strict;
    use warnings;
    use Moo;

    extends 'pf::services::manager';

    has '+name' => ( default => sub { 'foo' } );

    has '+launcher' => (default => sub { '%1$s -d' } );


=cut

use strict;

use Moo;
#with qw(pf::services::manager::systemd );
use pf::constants;
use pf::file_paths qw($var_dir $install_dir);
use pf::log;
use pf::util;

use File::Slurp qw(read_file);
use Proc::ProcessTable;
use List::Util qw(first);
use Linux::Inotify2;
use Errno qw(EINTR EAGAIN);
use Time::HiRes qw (alarm);
use Linux::FD::Timer;
use IO::Poll qw(POLLRDNORM POLLWRNORM POLLIN POLLHUP);

=head1 Attributes

=head2 name

name of service

=cut

has name => ( is => 'rw', required => 1);

=head2 shouldCheckup

if service requires checkup

=cut

has shouldCheckup => ( is => 'rw', default => sub { 1 } );

=head2 launcher

Method that launches the service.

=cut

has launcher => ( is => 'rw', lazy => 1, builder => '_build_launcher' );

=head2 startDependsOnServices

services that this service needs in order to start

=cut

has startDependsOnServices => (is => 'ro', default => sub { [qw( httpd.admin)] } );

=head2 stopDependsOnServices

Services that need to be stopped before this service can be stopped

=cut

has stopDependsOnServices => (is => 'ro', default => sub { [] });

=head2 orderIndex

Value to use when sorting services for the start or stop order.
Lower values start first and are stopped last.

=cut

has orderIndex => ( is => 'ro', builder => 1, lazy => 1 );

sub _build_orderIndex {
    my ($self) = @_;
    require pf::config;
    my $name = $self->name;
    $name =~ s/\./_/g ;
    my $index = $pf::config::Config{'services'}{"${name}_order"} // 100 ;
    return $index;
}

=head2 isvirtual

If the service is a virtual service

=cut

has isvirtual => ( is => 'rw', default => sub { 0 } );

=head2 forceManaged

If set then the service is forced to be considered managed

=cut

has forceManaged => ( is => 'rw', default => sub { 0 } );

=head2 optional

If set then the service will not cause an error if it fails to start

=cut

has optional => ( is => 'rw', default => sub { 0 } );

=head2 systemdFilePath  

The path to the systemd unit file for this service.

=cut

has systemdFilePath => (is => 'rw', builder => '_build_systemdFilePath', lazy => 1);

=head2 systemdTemplateFilePath

The path to the template used to generate the systemd unit file for this service.

=cut

has systemdTemplateFilePath => (is => 'rw', builder => '_build_systemdTemplateFilePath', lazy => 1);

=head1 Methods

=cut

=head2 start

start the service

=cut

sub start {
    my ($self,$quick) = @_;
    my $result = 0;
    unless ($self->status) {
        if( $self->preStartSetup($quick)) {
            if($self->startService($quick)) {
                $result = $self->postStartCleanup($quick);
            }
        }
    }
    return $result;
}

=head2 preStartSetup

Stub method to be implemented in services if needed.

=cut

sub preStartSetup {
    my ($self,$quick) = @_;
    return 1;
}

=head2 startService

Starts the service

=cut

sub startService {
    my ($self,$quick) = @_;
    return $self->launchService;
}

=head2 postStartCleanup

Stub method to be implemented in services if needed.

=cut

sub postStartCleanup {
    my ($self,$quick) = @_;
    my $logger = get_logger();
    unless ($self->pid) { 
        $logger->error("$self->name died or has failed to start");
        return $FALSE;
    }
    return $TRUE;
}


=head2 _build_launcher

Build the command to lauch the service.

=cut 
sub _build_launcher {
    my ($self) = @_;
    my $name = $self->{name};
    return "sudo systemctl start packetfence-" . $name;
}


=head2 restart

restart the service

=cut

sub restart {
    my ($self,$quick) = @_;
    $self->stop($quick);
    return $self->start($quick);
}

=head2 status

returns the pid or list of pids for the service(s)

=cut

sub status {
    my ($self,$quick) = @_;
    my $pid = $self->pid;
    return $pid ? $pid : "0";
}

=head2 pid

Returns the pid of the service

=cut

sub pid {
    my ($self) = @_;
    my $logger = get_logger();
    my $name = $self->{name};
    my $pid = `systemctl show -p MainPID packetfence-$name`;
    chomp $pid;
    $pid = (split(/=/, $pid))[1];
    $logger->debug("systemctl packetfence-$name returned $pid");
    return $pid;
}

=head2 stop

Stop the service waiting for it to shutdown

=cut

sub stop {
    my ($self,$quick) = @_;
    my @pids = $self->pid;
    if (@pids) {
        $self->preStopSetup($quick);
        $self->stopService($quick);
        $self->postStopCleanup($quick);
        return 1;
    }
    return;
}


=head2 preStopSetup

Stub. Implement in subclasses if needed.

=cut

sub preStopSetup {
    my ($self) = @_;
    return 1;
    
}

=head2 stopService

=cut

sub stopService {
    my ($self) = @_;
    my $name = $self->name;
    my $logger = get_logger();
    my $pid    = $self->pid;
    $logger->info("Stopping $name with pid $pid");
    `sudo systemctl stop packetfence-$name`;
    if ( $? == -1 ) {
        $logger->error("failed to execute: $!\n");
    }
    elsif ( $? & 127 ) {
        $logger->error("child died with signal %d, %s coredump\n", ( $? & 127 ), ( $? & 128 ) ? 'with' : 'without');
    }
    else {
        $logger->info("child exited with value %d\n", $? >> 8);
    }
}

=head2 postStopCleanup

Checks to see if the process is still running.
Override in subclasses to perform additonal cleanup actions.

=cut

sub postStopCleanup {
    my ($self,$quick) = @_;
    my $logger = get_logger();
    if ($self->pid) { 
        $logger->error("$self->name failed to stop");
        return $FALSE;
    }
    return $TRUE;
}

=head2 _build_systemdFilePath 

Return the fully qualified path to the systemd unit file output by generateUnitFile.

=cut 

sub _build_systemdFilePath {
    my $self = shift;
    return $install_dir . "/var/conf/systemd/packetfence-" . $self->name . ".service";
}

=head2 _build_systemdTemplateFilePath 

Return the fully qualified path to the template file used as input to generateUnitFile.

=cut

sub _build_systemdTemplateFilePath {
    my $self = shift;
    return $install_dir . "/conf/systemd/packetfence-" . $self->name . ".service.tt";
}

=head2 createSystemdVars 

Return a hashref with the variables requied to populate the systemd Unit File template in generateUnitFile. 
Stub, implement in subclasses as required.

=cut

sub createSystemdVars {
    my $self = shift;
    return {
        header_warning => "This file is generated dynamically based on the PacketFence configuration. 
        # Look under $self->systemdTemplateFilePath
        # for the template used to generate it."
    };
}

=head2 generateUnitFile

Generates the systemd unit file for the service.

=cut

sub generateUnitFile {
    my $self = shift;
    my $vars = $self->createSystemdVars();
    my $tt   = Template->new( ABSOLUTE => 1 );
    $tt->process( $self->systemdTemplateFilePath, $vars, $self->systemdFilePath ) or die $tt->error();
}

=head2 generateConfig

generates the configuration files for the service

=cut

sub generateConfig { 1 }

=head2 launchService

launch the service using the launcher and arguments passed

=cut

sub launchService {
    my ($self) = @_;
    my $cmdLine = $self->_cmdLine;
    if ($cmdLine =~ /^(.+)$/) {
        $cmdLine = $1;
        my $logger = get_logger();
        $logger->debug(sprintf("Starting Daemon %s with command %s",$self->name,$cmdLine));
        my $t0 = Time::HiRes::time();
        my $return_value = system($cmdLine);
        my $elapsed = Time::HiRes::time() - $t0;
        $logger->info(sprintf("Daemon %s took %.3f seconds to start.", $self->name, $elapsed));
        return $return_value == 0;
    }
    return;
}

=head2 _cmdLine

Build the command string from the launcher and the cmdLineArgs

=cut

sub _cmdLine {
    my ($self) = @_;
    return $self->launcher;
}


=head2 _cmdLineArgs

Return the list if values to replace in the launcher

=cut

sub _cmdLineArgs {
    my ($self) = @_;
    return undef;
}


=head2 pidFile

return the pid file of the service

=cut

sub pidFile {
    my ($self) = @_;
    my $name = $self->name;
    return "$var_dir/run/$name.pid";
}


=head2 isAlive

checks if process is alive

=cut

sub isAlive {
    my ($self,$pid) = @_;
    my $result;
    $pid = $self->pid unless defined $pid;
    eval {
        $result = pf_run("sudo kill -0 $pid >/dev/null 2>&1", (accepted_exit_status => [ 0 ]));
    };
    if($@ || !defined($result)){
        return $FALSE;
    }
    else {
        return $TRUE;
    }
}


=head2 isManaged

return true is the service is currently managed by packetfence

=cut

sub isManaged {
    my ($self) = @_;
    require pf::config;
    my $name = $self->name;
    $name =~ s/\./_/g;
    return $self->forceManaged || isenabled($pf::config::Config{'services'}{$name});
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

