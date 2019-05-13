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
use pf::constants;
use pf::file_paths qw($var_dir $install_dir $systemd_unit_dir);
use pf::log;
use pf::util;
use pf::util::console;

use Term::ANSIColor;

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

has pidFile => ( is => 'ro', lazy => 1, builder => '_buildpidFile' );

sub _buildpidFile { my $self = shift; return $var_dir . "/run/" . $self->name . ".pid"; }

=head2 executable

executable of service

=cut

has executable => (is => 'rw', builder => 1, lazy => 1 );

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

Stub. Implement as needed in subclasses.

=cut

sub preStartSetup {
    my ( $self, $quick ) = @_;
    unless ( $self->isEnabled ) {
        $self->sysdEnable();
    }
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

=head2 _build_executable
the builder the executable attribute
=cut

sub _build_executable {
    my ($self) = @_;
    require pf::config;
    my $name = $self->name;
    my $service = ( $pf::config::Config{'services'}{"${name}_binary"} || "$install_dir/sbin/$name" );
    return $service;
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


sub print_status {
    my ($self) = @_;
    my @output = `systemctl --all --no-pager`;
    my $header = shift @output;
    my $name   = $self->name;
    my $colors = pf::util::console::colors();
    my $loop = $TRUE;
    for my $output (@output) {
        if ($output =~ /(packetfence-$name\.service)\s+loaded\s+active/) {
            my $service = $1;
            $service .= (" " x (50 - length($service)));
            print "$service\t$colors->{success}started   ".$self->pid."$colors->{reset}\n";
            $loop = $FALSE;
        } elsif ($output =~ /(packetfence-$name\.service)\s+loaded.*/) {
            my $service = $1;
            if ($name =~ /(radiusd).*/) {
                $name = $1;
            }
            my $manager = pf::services::get_service_manager($name);
            my $isManaged = $manager->isManaged;
            $service .= (" " x (50 - length($service)));
            if ($isManaged && !$manager->optional) {
                print "$service\t$colors->{error}stopped   ".$self->pid."$colors->{reset}\n";
            } else {
                print "$service\t$colors->{warning}stopped   ".$self->pid."$colors->{reset}\n";
            }
            $loop = $FALSE;
        }
    }
    if ($loop) {
       my $service = "packetfence-$name.service";
       $service .= (" " x (50 - length($service)));
       print "$service\t$colors->{warning}disabled  ".$self->pid."$colors->{reset}\n";
    }
}

=head2 pid

Returns the pid of the service

=cut

sub pid {
    my ($self) = @_;
    my $logger = get_logger();
    my $name = $self->{name};
    my $pid = `sudo systemctl show -p MainPID packetfence-$name`;
    chomp $pid;
    $pid = (split(/=/, $pid))[1];
    if (defined $pid) {
        $logger->debug("sudo systemctl packetfence-$name returned $pid");
    } else {
        $logger->error("Error getting pid for $name");
    }
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
        $logger->error(sprintf("child died with signal %d, %s coredump\n", 
                ( $? & 127 ), 
                (( $? & 128 ) ? 'with' : 'without')));
    }
    else {
        $logger->info(sprintf("child exited with value %d\n", $? >> 8));
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

=head2 generateConfig

generates the configuration files for the service

=cut

sub generateConfig { 1 }

=head2 launchService

launch the service using the launcher and arguments passed

=cut

sub launchService {
    my ($self) = @_;
    my $cmdLine = $self->launcher;
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
    return $self->executable;
}


=head2 _cmdLineArgs

Return the list if values to replace in the launcher

=cut

sub _cmdLineArgs {
    my ($self) = @_;
    return undef;
}



=head2 isAlive

checks if process is alive

=cut

sub isAlive {
    my ($self) = @_;
    my $logger = get_logger();
    my $name = $self->{name};
    my $res = system("sudo systemctl status packetfence-$name &> /dev/null");
    my $alive = $res == 0 ? 1 : 0;
    $logger->debug("sudo systemctl status packetfence-$name returned code $res");
    return $alive;
}



=head2 isManaged

return true is the service is currently managed by packetfence

=cut

sub isManaged {
    my ($self) = @_;
    require pf::config;
    my $name = $self->name;
    $name =~ s/\./_/g;
    return $self->forceManaged
      || isenabled( $pf::config::Config{'services'}{$name} );
}

=head2 isEnabled

Return true if systemd consider the service as enabled

=cut 

sub isEnabled {
    my ($self) = @_;
    my $name   = $self->name;
    my $state  = `sudo systemctl show -p UnitFileState packetfence-$name`;
    chomp $state;
    $state = ( split( /=/, $state ) )[1];
    if ( defined $state and $state eq "enabled" ) {
        return $TRUE;
    }
    else {
        return $FALSE;
    }
}

=head2 systemdTarget

systemdTarget

=cut

sub systemdTarget {
    my ($self) = @_;
    return "packetfence-" . $self->name;
}

=head2 sysdEnable 

Enable the service in systemd.

=cut

sub sysdEnable {
    my $self = shift;
    return system( "sudo systemctl enable " . $self->systemdTarget) == 0;
}

=head2 sysdDisable

Disable the service in systemd.

=cut

sub sysdDisable {
    my $self = shift;
    return system( "sudo systemctl disable " . $self->systemdTarget) == 0;
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
