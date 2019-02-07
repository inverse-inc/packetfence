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
    $domains_chroot_dir
);
use pf::domain;

extends 'pf::services::manager';

has '+name' => (default => sub { 'winbindd'} );

sub isManaged {
    my ($self) = @_;
    return $TRUE if (keys %ConfigDomain);
    return $FALSE;
}

sub generateConfig {
    my ($self, $quick) = @_;

    $self->_refresh_domains();

    $self->build_namespaces();
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
    return 1;
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

