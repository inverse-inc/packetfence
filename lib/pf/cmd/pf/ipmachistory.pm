package pf::cmd::pf::ipmachistory;
=head1 NAME

pf::cmd::pf::ipmachistory add documentation

=head1 SYNOPSIS

pfcmd ipmachistory <ip|mac> [start_date=<date>,end_time=<date>]

get the MAC/IP mapping for a specified IP or MAC with optional date (in mysql format)

examples:
  pfcmd ipmachistory 192.168.1.100
  pfcmd ipmachistory 192.168.1.100 start_time=2006-10-12 15:00:00,end_time=2006-10-18 12:00:00

=head1 DESCRIPTION

pf::cmd::pf::ipmachistory

=cut

use strict;
use warnings;
use base qw(pf::cmd::display);

sub parseArgs {
    my ($self) = @_;
    my ($key,$start_time,$end_time) = $self->args;
    if($key) {
        require pf::iplog;
        import pf::iplog;
        my ($function,%params);
        if ($key =~ /^(\d{1,3}\.){3}\d{1,3}$/ ) {
            $function = \&iplog_history_ip;
        } else {
            $function = \&iplog_history_mac;
        }
        $params{'start_time'} = str2time( $start_time) if defined $start_time;
        $params{'end_time'} = str2time( $end_time) if defined $end_time;
        $self->{params} = \%params;
        $self->{key} = $key;
        $self->{function} = $function;
        return 1;
    }
    return 0;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

