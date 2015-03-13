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
use pf::config;
use pf::util;
use List::MoreUtils qw(any all uniq);
use Linux::Inotify2;
use Errno qw(EINTR EAGAIN);
use pf::log;
use pf::file_paths;
use pf::domain;
use pfconfig::manager;

extends 'pf::services::manager::submanager';

has winbinddManagers => (is => 'rw', builder => 1, lazy => 1);

has _pidFiles => (is => 'rw', default => sub { {} } );

has '+name' => (default => sub { 'winbindd'} );

sub _build_winbinddManagers {
    my ($self) = @_;

    # we want to refresh the domain list to the latest available
    # when restarting the service
    # Restarting through pfcmd service pf restart does the configreload after the managers have been instanciated
    $self->_refresh_domains();

    $self->build_namespaces();

    my @managers = map {
        my $DOMAIN=$_;
        my $CHROOT_PATH=pf::domain::chroot_path($DOMAIN);
        my $CONFIGFILE="/etc/samba/$DOMAIN.conf";
        my $LOGDIRECTORY="/var/log/samba$DOMAIN";
        my $binary = $Config{services}{winbindd_binary};

        pf::services::manager->new ({
            executable => $self->executable,
            name => "winbindd-$_.conf",
            launcher => "sudo chroot $CHROOT_PATH $binary -D -s $CONFIGFILE -l $LOGDIRECTORY",
            forceManaged => $self->isManaged,
        })
    } uniq keys %ConfigDomain;
    return \@managers;
}

sub _refresh_domains {
    my ($self) = @_;
    pfconfig::manager->new->expire("config::Domain");
}

sub build_namespaces(){
    my ($self) = @_;

    my $out = pf_run("sudo /sbin/ip netns list");
    foreach my $net (split /\n/, $out) {
        # untaint the variable
        $net =~ m|([\w\-\/]*)|;
        $net = $1;
        my @args = ("sudo", "ip", "link", "delete", "$net-b");
        system(@args);
        @args = ("sudo", "ip", "netns", "delete", $net);
        system(@args);

    } 

    my $i = 1;

    foreach my $domain (keys %ConfigDomain){
        my $CHROOT_PATH=pf::domain::chroot_path($domain);
        my $LOGDIRECTORY="/var/log/samba$domain";
        my $OUTERLOGDIRECTORY="$CHROOT_PATH/$LOGDIRECTORY";
        my $OUTERRUNDIRECTORY="$CHROOT_PATH/var/run/samba$domain";
        pf_run("sudo mkdir -p $OUTERLOGDIRECTORY && sudo chown root.root $OUTERLOGDIRECTORY");
        pf_run("sudo mkdir -p $OUTERRUNDIRECTORY && sudo chown root.root $OUTERRUNDIRECTORY");

        pf_run("sudo /usr/local/pf/addons/create_chroot.sh $domain $domains_chroot_dir");
        my $ip_a = "169.254.0.".$i;
        my $ip_b = "169.254.0.".($i+1);
        pf_run("sudo ip netns add $domain");
        pf_run("sudo ip link add $domain-a type veth peer name $domain-b");
        pf_run("sudo ip link set $domain-a netns $domain");
        pf_run("sudo ip netns exec $domain ifconfig $domain-a up $ip_a netmask 255.255.255.252");
        pf_run("sudo ifconfig $domain-b up $ip_b netmask 255.255.255.252");
        pf_run("sudo ip netns exec $domain route add default gw $ip_b dev $domain-a");
        pf_run("sudo ip netns exec $domain ip link set dev lo up");
        $i+=4;
    }
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
    return @{$self->winbinddManagers};
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

