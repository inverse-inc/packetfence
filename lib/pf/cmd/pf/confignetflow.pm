package pf::cmd::pf::confignetflow;

=head1 NAME

pf::cmd::pf::confignetflow

=head1 SYNOPSIS

pfcmd confignetflow

=head1 DESCRIPTION

Configures the netflow kernel module

=cut

use strict;
use warnings;
use base qw(pf::cmd);
use pf::config qw(%Config netflow_enabled);
use pf::util;
use pf::log;
use Symbol 'gensym';
use IPC::Open3;
use Socket;
use Net::IP;
our $IPT_NETFLOW_VERSION;
our $os = pf::util::os_detection();
if ($os eq 'rhel') {
    $IPT_NETFLOW_VERSION = qx{ rpm -q ipt-netflow --queryformat "%{VERSION}-%{RELEASE}"};
    chomp($IPT_NETFLOW_VERSION);
    if ($IPT_NETFLOW_VERSION =~ /^(.*)$/) {
        $IPT_NETFLOW_VERSION = $1;
    }
} elsif ($os eq 'debian') {
    $IPT_NETFLOW_VERSION = qx{dpkg-query -W -f \\\${Version} iptables-netflow-dkms};
    chomp($IPT_NETFLOW_VERSION);
    if ($IPT_NETFLOW_VERSION =~ /^(.*)-\d$/) {
        $IPT_NETFLOW_VERSION = $1;
    }
}

sub _run {
    if (!netflow_enabled()) {
        return 0;
    }

    my $stderr = gensym;
    my ($pid, $child_exit_status);;

    system("/usr/sbin/dkms", "-q", "install", "-m", "ipt-netflow", "-v", $IPT_NETFLOW_VERSION);
    system("/sbin/modprobe", "ipt_NETFLOW");
    local $SIG{PIPE} = sub {};
    my @destination = split(':',$Config{services}{netflow_target_host_port});
    my $destination_ip;
    if (Net::IP::ip_is_ipv4($destination[0])) {
        $destination_ip = $destination[0];
    } else {
        $destination_ip = inet_ntoa(inet_aton($destination[0]));
    }
    $pid = open3('>&STDIN', '>&STDOUT', $stderr = gensym,'/sbin/sysctl',"net.netflow.destination=$destination_ip:$destination[1]");
    waitpid($pid, 0);
    $child_exit_status = $? >> 8;
    if ($child_exit_status) {
        my $error = <$stderr>;
        $error .= "kernel module ipt_NETFLOW is not configured or loaded";
        get_logger()->error($error);
        print STDERR "${error}\n";
    }

    close $stderr;
    return $child_exit_status;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

