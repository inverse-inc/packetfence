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


To include the new service in pfcmd service

* Add service name to the service regex in pf::pfcmd

* Update the help in pf::pfcmd::help

=cut

use strict;

use pf::file_paths;
use pf::log;
use pf::util;
use Moo;
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

sprintf-formatted string that control how the services should be started
  %1$s: is the service executable
  %2$s: optional parameters

=cut

has launcher => ( is => 'rw', lazy => 1);

=head2 dependsOnServices

services that this service needs in order to start

=cut

has dependsOnServices => (is => 'ro', default => sub { [qw(memcached httpd.admin)] } );

=head2 executable

executable of service

=cut

has executable => (is => 'rw', builder => 1, lazy => 1 );

=head2 lastPid

The last pid retrived from the pidFile

=cut

has lastPid => (is => 'rw');

=head2 inotify

The inotify object used to watch for pidfile

=cut

has inotify => (is => 'rw', builder => 1, lazy => 1 );

=head2 isvirtual

If the service is a virtual service

=cut

has isvirtual => ( is => 'rw', default => sub { 0 } );

=head2 forceManaged

If set then the service is forced to be considered managed

=cut

has forceManaged => ( is => 'rw', default => sub { 0 } );


=head1 Methods

=head2 _build_inotify

builds the inotify object

=cut

sub _build_inotify {
    return Linux::Inotify2->new;
}

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

work for starting a servicw

=cut

sub preStartSetup {
    my ($self,$quick) = @_;
    $self->removeStalePid($quick);
    $self->generateConfig($quick) unless $quick;
    $self->_setupWatchForPidCreate;
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

Cleanup work after the starting the service

=cut

sub postStartCleanup {
    my ($self,$quick) = @_;
    my $pidFile = $self->pidFile;
    $pidFile = untaint_chain($pidFile);
    my $result = 0;
    my $inotify = $self->inotify;
    unless (-e $pidFile) {
        my $timedout;
        eval {
            local $SIG{ALRM} = sub { die "alarm clock restart" };
            alarm 60;
            eval {
                 1 while $inotify->poll && !-e $pidFile;
            };
            alarm 0;
            $timedout = 1 if $@ && $@ =~ /^alarm clock restart/;
        };
        alarm 0;
        my $logger = get_logger;
        $logger->warn($self->name . " timed out trying to start" ) if $timedout;
    }
    return -e $pidFile;
}


=head2 _setupWatchForPidCreate

This setups a watch on the run directory to wait for the pid to

=cut

sub _setupWatchForPidCreate {
    my ($self) = @_;
    my $inotify = $self->inotify;
    my $pidFile = $self->pidFile;
    my $run_dir = "$var_dir/run";
    $inotify->watch ($run_dir, IN_CREATE, sub {
        my $e = shift;
        my $name = $e->fullname;
        if($pidFile eq $name) {
             $e->w->cancel;
        }
    });
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

returns the pid or list of pids for the servie(s)

=cut

sub status {
    my ($self,$quick) = @_;
    $self->removeStalePid($quick);
    my $pid = $self->pid;
    return $pid ? $pid : "0";
}

=head2 pid

Returns the pid of the service

=cut

sub pid {
    my ($self) = @_;
    $self->lastPid($self->pidFromFile);
    return $self->lastPid;
}

=head2 stop

Stop the service waitinf for it to shutdown

=cut

sub stop {
    my ($self,$quick) = @_;
    my $pid = $self->pid;
    if ($pid) {
        $self->preStopSetup($quick);
        $self->stopService($quick);
        $self->postStopCleanup($quick);
        return 1;
    }
    return;
}


=head2 preStopSetup

the pre stop setup

=cut

sub preStopSetup {
    my ($self) = @_;
    $self->inotify->watch($self->pidFile, IN_DELETE_SELF);
}

=head2 stopService

=cut

sub stopService {
    my ($self) = @_;
    my $name = $self->name;
    my $logger = get_logger();
    my $pid = $self->lastPid;
    $logger->info("Sending TERM signal to $name with pid $pid");
    my $count = kill 'TERM',$pid;
}

=head2 postStopCleanup

=cut

sub postStopCleanup {
    my ($self,$quick) = @_;
    my $logger = get_logger();
    my $name = $self->name;
    my $pid = $self->lastPid;
    my $inotify = $self->inotify;
    my $pidFile = $self->pidFile;
    my $timedout;
    #give the kill a little time
    $inotify->blocking(0);
    $self->removeStalePid($quick);
    my $timer = Linux::FD::Timer->new('monotonic');
    $timer->set_timeout(0.1,0.1);
    $timer->receive;
    eval {
        local $SIG{ALRM} = sub { die "alarm clock restart" };
        alarm 60;
        eval {
            until($inotify->read) {
                die $! if defined $! && $! != EINTR && $! != EAGAIN;
                $self->removeStalePid;
                #give it some time
                $timer->receive;
            }
        };
        alarm 0;
        $timedout = 1 if $@ && $@ =~ /^alarm clock restart/;
        $logger->error("Error: $@") if $@;
    };
    alarm 0;
    $logger->info("Timed out waiting for process $name to stop") if $timedout;
    if ($self->isAlive($pid)) {
        kill 'KILL',$pid;
    }
    $self->removeStalePid;
}

=head2 watch

If the service is stopped start the service

=cut

sub watch {
    my ($self) = @_;
    $self->removeStalePid;
    unless($self->pid) {
        return $self->start(1);
    }
    return;
}

=head2 generateConfig

generates the configuration files for the service

=cut

sub generateConfig { 1 }

=head2 launchService

launch the service using the launcher and arguements passed

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

TODO: documention

=cut

sub _cmdLine {
    my ($self) = @_;
    my $launcher = $self->launcher;
    $launcher =~ /^(.*)$/;
    $launcher = $1;
    my @cmdLineArgs = map { /^(.*)$/;$1 }  $self->_cmdLineArgs;
    my $cmdLine = sprintf($launcher, map { /^(.*)$/;$1 }  @cmdLineArgs);
    return $cmdLine;
}


=head2 _cmdLineArgs

TODO: documention

=cut

sub _cmdLineArgs {
    my ($self) = @_;
    return ($self->executable);
}


=head2 pidFile

return the pid file of the service

=cut

sub pidFile {
    my ($self) = @_;
    my $name = $self->name;
    return "$var_dir/run/$name.pid";
}

=head2 pidFromFile

get the pid from the pid file

=cut

sub pidFromFile {
    my ($self) = @_;
    my $name = $self->name;
    my $logger = Log::Log4perl::get_logger('pf::services');
    my $pid;
    my $pid_file = $self->pidFile;
    if (-e $pid_file) {
        eval {chomp( $pid = read_file($pid_file) );};
    }
    $pid = 0 unless $pid;
    if($pid) {
        $logger->info("pidof -x $name returned $pid");
        if($pid =~ /^\s*(\d*)\s*$/) {
            $pid = $1;
        }
    }
    return $pid;
}

=head2 removeStalePid

removes the stale PID file

=cut

sub removeStalePid {
    my ($self,$quick) = @_;
    return if $quick;
    my $logger = get_logger;
    my $pid = $self->pidFromFile;
    my $pidFile = $self->pidFile;
    $pidFile = untaint_chain($pidFile);
    if($pid && $pid =~ /^(.*)$/) {
        $pid = $1;
        $logger->info("verifying process $pid");
        my $result = $self->isAlive;
        unless ($result) {
            $logger->info("removing stale pid file $pidFile");
            unlink $pidFile if -e $pidFile;
        }
    }
}

=head2 isAlive

checks if process is alive

=cut

sub isAlive {
    my ($self,$pid) = @_;
    my $result;
    $pid = $self->pid unless defined $pid;
    $result = kill 0 , $pid if $pid;
    return $result;
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

