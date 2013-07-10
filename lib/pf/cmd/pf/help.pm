package pf::cmd::pf::help;
=head1 NAME

pfcmd - PacketFence command line interface

=head1 SYNOPSIS

pfcmd <command> [options]

 Commands
  checkup                     | perform a sanity checkup and report any problems
  class                       | view violation classes
  config                      | query, set, or get help on pf.conf configuration paramaters
  configfiles                 | push or pull configfiles into/from database
  floatingnetworkdeviceconfig | query/modify floating network devices configuration parameters
  fingerprint                 | view DHCP Fingerprints
  graph                       | trending graphs
  history                     | IP/MAC history
  ifoctetshistorymac          | accounting history
  ifoctetshistoryswitch       | accounting history
  ifoctetshistoryuser         | accounting history
  import                      | bulk import of information into the database
  interfaceconfig             | query/modify interface configuration parameters
  ipmachistory                | IP/MAC history
  locationhistorymac          | Switch/Port history
  locationhistoryswitch       | Switch/Port history
  lookup                      | node or pid lookup against local data store
  manage                      | manage node entries
  networkconfig               | query/modify network configuration parameters
  node                        | node manipulation
  nodeaccounting              | RADIUS Accounting Information
  nodecategory                | nodecategory manipulation
  nodeuseragent               | View User-Agent information associated to a node
  person                      | person manipulation
  reload                      | rebuild fingerprint or violations tables without restart
  report                      | current usage reports
  schedule                    | Nessus scan scheduling
  service                     | start/stop/restart and get PF daemon status
  switchconfig                | query/modify switches.conf configuration parameters
  switchlocation              | view switchport description and location
  traplog                     | update traplog RRD files and graphs or obtain
  switch IPs
  trigger                     | view and throw triggers
  ui                          | used by web UI to create menu hierarchies and dashboard
  update                      | download canonical fingerprint or OUI data
  useragent                   | view User-Agent fingerprint information
  version                     | output version information
  violation                   | violation manipulation
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

