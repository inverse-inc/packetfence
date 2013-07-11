package pf::cmd::pf::ifoctetshistoryswitch;
=head1 NAME

pf::cmd::pf::ifoctetshistoryswitch add documentation

=head1 SYNOPSIS

pfcmd ifoctetshistoryswitch switch ifIndex

get the bytes throughput through a specified switch port with optional date

examples:
  pfcmd ifoctetshistoryswitch 192.168.0.1 10
  pfcmd ifoctetshistoryswitch 192.168.0.1 10 start_time=2007-10-12 10:00:00,end_time=2007-10-13 10:00:00tetslog;

=head1 DESCRIPTION

pf::cmd::pf::ifoctetshistoryswitch

=cut

use strict;
use warnings;
use pf::ifoctetslog;
use base qw(pf::cmd::display);
use pf::cmd::roles::show_help;

sub parseArgs {
    my ($self) = @_;
    my ($switch,$ifIndex,$start_time,$end_time) = $self->args;
    if ($switch) {
        my %params = (ifIndex => $ifIndex);
        $params{'start_time'} = str2time( $start_time) if defined $start_time;
        $params{'end_time'} = str2time( $end_time) if defined $end_time;
        $self->{key} = $switch;
        $self->{params} = \%params;
        $self->{function} = \&ifoctetslog_history_switchport;
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

