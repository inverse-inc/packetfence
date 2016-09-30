package pf::services::manager::winbindd_child;

=head1 NAME

pf::services::manager::winbindd_child

=cut

=head1 DESCRIPTION

pf::services::manager::winbindd_child

Used to create the childs of the submanager winbindd
The first manager will create the namespaces for all winbindd processes through the global variable.


=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw($domains_chroot_dir $var_dir);
use pf::config qw(%ConfigDomain $DISTRIB $DIST_VERSION);
use pf::util;
use pfconfig::manager;
use Linux::Inotify2;
extends 'pf::services::manager';

has domain => (is => 'rw');

our $CONFIG_GENERATED = 0;

sub generateConfig {
    my ($self, $quick) = @_;

    unless($CONFIG_GENERATED){
        # we want to refresh the domain list to the latest available
        # when restarting the service
        # Restarting through pfcmd service pf restart does the configreload after the managers have been instanciated
        $self->_refresh_domains();

        $self->build_namespaces();

        $CONFIG_GENERATED = 1;
    }

}

sub _refresh_domains {
    my ($self) = @_;
    pfconfig::manager->new->expire("config::Domain");
}

sub build_namespaces(){
    my ($self) = @_;

    my $out = pf_run("sudo /sbin/ip netns list");
    if (defined $out) {
        foreach my $net (split /\n/, $out) {
            # untaint the variable
            $net =~ m|([\w\-\/]*)|;
            $net = $1;
            my @args = ("sudo", "ip", "link", "delete", "$net-b");
            system(@args);
            @args = ("sudo", "ip", "netns", "delete", $net);
            system(@args);
        }
    }

    my $i = 1;

    foreach my $domain (keys %ConfigDomain){
        my $CHROOT_PATH=pf::domain::chroot_path($domain);
        my $LOGDIRECTORY="/var/log/samba$domain";
        my $OUTERLOGDIRECTORY="$CHROOT_PATH/$LOGDIRECTORY";
        my $OUTERRUNDIRECTORY="$CHROOT_PATH/var/run/samba$domain";
        my $PIDDIRECTORY="$var_dir/run/$domain";
        pf_run("sudo mkdir -p $OUTERLOGDIRECTORY && sudo chown root.root $OUTERLOGDIRECTORY");
        pf_run("sudo mkdir -p $OUTERRUNDIRECTORY && sudo chown root.root $OUTERRUNDIRECTORY");
        pf_run("sudo mkdir -p $PIDDIRECTORY && sudo chown root.root $PIDDIRECTORY");
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

=head2 pidFile

return the pid file of the service

=cut

sub pidFile {
    my ($self) = @_;
    my $name = $self->name;
    my $domain = $self->domain;
    if (( ( ($DISTRIB eq 'centos') || ($DISTRIB eq 'redhat') ) && ($DIST_VERSION gt 7)) || ( ($DISTRIB eq 'debian') && ($DIST_VERSION gt 8) ) ) {
        return "$var_dir/run/$domain/winbindd.pid";
    } else {
        return "$var_dir/run/$domain/$name.pid";
    }
}

=head2 _setupWatchForPidCreate

This setups a watch on the run directory and its childs to wait for the pid file to appear

=cut

sub _setupWatchForPidCreate {
    my ($self) = @_;
    my $inotify = $self->inotify;
    my $pidFile = $self->pidFile;
    my $run_dir = "$var_dir/run";
    my @dirs = ($run_dir);
    opendir(DIR, $run_dir);
    while(readdir DIR) {
        push @dirs, "$run_dir/$_" if defined($_);
    }
    closedir(DIR);
    foreach my $dir (@dirs) {
        $inotify->watch ($dir, IN_CREATE, sub {
            my $e = shift;
            my $name = $e->fullname;
            if($pidFile eq $name) {
                 $e->w->cancel;
            }
        });
    }
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
