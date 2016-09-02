package pf::services::manager::winbindd;

=head1 NAME

pf::services::manager::winbindd add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::winbindd

=cut

use strict;
use warnings;
use Moo;
use pf::config qw(
    %ConfigDomain
    %Config
);
use pf::constants qw($TRUE $FALSE);
use pf::util;
use List::MoreUtils qw(any all uniq);
use Linux::Inotify2;
use Errno qw(EINTR EAGAIN);
use pf::log;
use pf::file_paths qw(
    $var_dir
);
use pf::domain;
use pf::services::manager::winbindd_child;

extends 'pf::services::manager::submanager';

has winbinddManagers => (is => 'rw', builder => 1, lazy => 1);

has _pidFiles => (is => 'rw', default => sub { {} } );

has '+name' => (default => sub { 'winbindd'} );

sub _build_winbinddManagers {
    my ($self) = @_;

    my @managers = map {
        my $DOMAIN=$_;
        my $CHROOT_PATH=pf::domain::chroot_path($DOMAIN);
        my $CONFIGFILE="/etc/samba/$DOMAIN.conf";
        my $LOGDIRECTORY="/var/log/samba$DOMAIN";
        my $binary = $Config{services}{winbindd_binary};

        pf::services::manager::winbindd_child->new ({
            executable => $self->executable,
            name => "winbindd-$_.conf",
            launcher => "sudo chroot $CHROOT_PATH $binary -d 10 -D -s $CONFIGFILE -l $LOGDIRECTORY",
            forceManaged => $self->isManaged,
            orderIndex => $self->orderIndex,
            domain => $_,
        })
    } uniq keys %ConfigDomain;
    return \@managers;
}



=head2 _setupWatchForPidCreate

Setting up inotify to watch for the creation of pidFiles for each winbindd instance

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
    my $logger = get_logger();
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
    return @{$self->winbinddManagers};
}

sub isManaged {
    my ($self) = @_;
    return $TRUE if (keys %ConfigDomain);
    return $FALSE;
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

1;

