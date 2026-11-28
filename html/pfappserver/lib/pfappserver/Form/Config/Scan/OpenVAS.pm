package pfappserver::Form::Config::Scan::OpenVAS;

=head1 NAME

pfappserver::Form::Config::Scan::OpenVAS - Web form to add a OpenVAS Scan Engine

=head1 DESCRIPTION

Form definition to create or update a OpenVAS Scan Engine.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Scan';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use pf::constants::scan qw($OPENVAS_DEFAULT_CONFIG_ID $OPENVAS_DEFAULT_SCANNER_ID $OPENVAS_DEFAULT_PORT_LIST_ID $OPENVAS_DEFAULT_DELETE_SCANS);
use File::Find qw(find);

has_field 'ip' =>
  (
   type => 'Text',
   label => 'Hostname or IP Address',
   required => 1,
   messages => { required => 'Please specify the hostname or IP of the scan engine' },
  );

has_field 'port' =>
  (
   type => 'Port',
   label => 'SSH port of the GMP service',
   tags => { after_element => \&help,
             help => 'Port of the SSH service giving access to the Greenbone Management Protocol (GMP)' },
   default => 22,
  );

has_field 'type' =>
  (
   type => 'Hidden',
   default => 'openvas',
  );

has_block definition =>
  (
   render_list => [ qw(id ip type username password port openvas_ssh_username openvas_ssh_password openvas_alertid openvas_configid openvas_scannerid openvas_portlistid openvas_delete_scans categories oses duration pre_registration registration post_registration) ],
  );

has_field 'openvas_ssh_username' =>
  (
   type => 'Text',
   label => 'SSH username',
   required => 1,
   messages => { required => 'Please specify the SSH username of the GMP service' },
   tags => { after_element => \&help,
             help => 'SSH user giving access to the Greenbone Management Protocol (GMP) on the OpenVAS server' },
  );

has_field 'openvas_ssh_password' =>
  (
   type => 'ObfuscatedText',
   label => 'SSH password',
   required => 1,
   messages => { required => 'Please specify the SSH password of the GMP service' },
   tags => { after_element => \&help,
             help => 'Password of the SSH user' },
  );

has_field 'openvas_alertid' =>
  (
   type => 'Text',
   label => 'Alert ID',
   tags => { after_element => \&help,
             help => 'ID of the alert configuration on the OpenVAS server' },
  );

has_field 'openvas_configid' =>
  (
   type => 'Text',
   label => 'Scan config ID',
   default => $OPENVAS_DEFAULT_CONFIG_ID,
   tags => { after_element => \&help,
             help => 'ID of the scanning configuration on the OpenVAS server' },
  );

has_field 'openvas_scannerid' =>
  (
   type => 'Text',
   label => 'Scanner ID',
   default => $OPENVAS_DEFAULT_SCANNER_ID,
   tags => { after_element => \&help,
             help => 'ID of the scanner on the OpenVAS server' },
  );

has_field 'openvas_portlistid' =>
  (
   type => 'Text',
   label => 'Port list ID',
   default => $OPENVAS_DEFAULT_PORT_LIST_ID,
   tags => { after_element => \&help,
             help => 'ID of the port list on the OpenVAS server' },
  );

has_field 'openvas_delete_scans' =>
  (
   type => 'Checkbox',
   label => 'Delete scans',
   default => $OPENVAS_DEFAULT_DELETE_SCANS,
   tags => { after_element => \&help,
             help => 'Delete the task, its report and the target from the OpenVAS server once the report is processed' },
  );

=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;
