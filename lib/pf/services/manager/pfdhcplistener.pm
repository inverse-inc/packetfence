package pf::services::manager::pfdhcplistener;
=head1 NAME

pf::services::manager::pfdhcplistener add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::pfdhcplistener

=cut

use strict;
use warnings;
use Moo;
use pf::config;
use pf::util;
use List::MoreUtils qw(any all uniq);
use Linux::Inotify2;
use pf::log;

extends 'pf::services::manager::submanager';

has pfdhcplistenerManagers => (is => 'rw', builder => 1, lazy => 1);

has _pidFiles => (is => 'rw', default => sub { {} } );

has '+name' => (default => sub { 'pfdhcplistener'} );

sub _build_pfdhcplistenerManagers {
    my ($self) = @_;
    my @managers = map {
        pf::services::manager->new ({
            executable => $self->executable,
            name => "pfdhcplistener_$_",
            launcher => "sudo %1\$s -i '$_' -d &",
            forceManaged => $self->isManaged,
        })
    } uniq @listen_ints, @dhcplistener_ints;
    return \@managers;
}

=head2 _setupWatchForPidCreate

Setting up inotify to watch for the creation of pidFiles for each pfdhcplistener instance

=cut

sub _setupWatchForPidCreate {
    my ($self) = @_;
    my $inotify = $self->inotify;
    my %pidFiles = map { $_->pidFile => undef } $self->managers;
    my $run_dir = "$var_dir/run";
    $inotify->watch ($run_dir, IN_CREATE, sub {
        my $e = shift;
        delete @pidFiles{ grep { -e $_ } keys %pidFiles };
        $e->w->cancel unless keys %pidFiles;
    });
}

sub postStartCleanup {
    my ($self,$quick) = @_;
    my $result = 0;
    my $inotify = $self->inotify;
    my @pidFiles = map { $_->pidFile } $self->managers;
    my $logger = get_logger;
    if ( @pidFiles && any { ! -e $_ } @pidFiles ) {
        my $timedout;
        eval {
            local $SIG{ALRM} = sub { die "alarm clock restart" };
            alarm 60;
            eval {
                 1 while $inotify->poll;
            };
            alarm 0;
            $timedout = 1 if $@ && $@ =~ /^alarm clock restart/;
        };
        alarm 0;
        $logger->warn($self->name . " timed out trying to start" ) if $timedout;
    }
    return all { -e $_ } @pidFiles;
}

sub managers {
    my ($self) = @_;
    return @{$self->pfdhcplistenerManagers};
}

sub isManaged {
    my ($self) = @_;
    return (isenabled($Config{'network'}{'dhcpdetector'}) && isenabled($Config{'services'}{$self->name})) && (!$pf::cluster::cluster_enabled || pf::cluster::is_management());;
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

