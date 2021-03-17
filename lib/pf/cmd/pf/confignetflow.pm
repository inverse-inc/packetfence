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
use pf::config qw(%Config);
use pf::log;
use Symbol 'gensym';
use IPC::Open3;

sub _run {
    local $SIG{PIPE} = sub {};
    my $pid = open3('>&STDIN', '>&STDOUT', my $stderr = gensym,'/sbin/sysctl',"net.netflow.destination=$Config{services}{netflow_address}:$Config{ports}{pfacct_netflow}");

    waitpid($pid, 0);
    my $child_exit_status = $? >> 8;
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

Copyright (C) 2005-2021 Inverse inc.

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

