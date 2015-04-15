package pf::cmd::pf::help;
=head1 NAME

pfcmd - PacketFence command line interface

=head1 SYNOPSIS

pfcmd <command> [options]

 Commands
  cache                       | manage the cache subsystem
  checkup                     | perform a sanity checkup and report any problems
  class                       | view violation classes
  config                      | query, set, or get help on pf.conf configuration paramaters
  configfiles                 | push or pull configfiles into/from database
  fingerprint                 | view DHCP Fingerprints
  floatingnetworkdeviceconfig | query/modify floating network devices configuration parameters
  help                        | show help for pfcmd commands
  ifoctetshistorymac          | accounting history
  ifoctetshistoryswitch       | accounting history
  ifoctetshistoryuser         | accounting history
  import                      | bulk import of information into the database
  ipmachistory                | IP/MAC history
  locationhistorymac          | Switch/Port history
  locationhistoryswitch       | Switch/Port history
  networkconfig               | query/modify network configuration parameters
  portalprofileconfig         | query/modify portal profile configuration parameters
  reload                      | rebuild fingerprint or violations tables without restart
  service                     | start/stop/restart and get PF daemon status
  switchconfig                | query/modify switches.conf configuration parameters
  version                     | output version information
  violationconfig             | query/modify violations.conf configuration parameters

Please view "pfcmd help <command>" for details on each option

=cut

=head1 DESCRIPTION

pf::cmd::pf::help

=cut

use strict;
use warnings;

use base qw(pf::cmd::help);

sub run {
    my ($self) = @_;
    my ($cmd) = $self->args;
    if(!defined $cmd || $cmd eq 'help') {
        return $self->SUPER::run;
    }
    return $self->showHelp("pf::cmd::pf::${cmd}");
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

