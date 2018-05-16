package pfappserver::Form::Config::Scan::Rapid7;

=head1 NAME

pfappserver::Form::Config::Scan::Rapid7 - Web form to add a Rapid7 Scan Engine

=head1 DESCRIPTION

Form definition to create or update a Rapid7 Scan Engine.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Scan';
with qw(
    pfappserver::Base::Form::Role::Help
    pfappserver::Role::Form::RolesAttribute
);

use pf::config;
use pf::util;
use File::Find qw(find);

has_field 'type' =>
  (
   type => 'Hidden',
  );

has_field 'host' =>
  (
   type => 'Text',
   label => 'Hostname or IP Address',
   required => 1,
   messages => { required => 'Please specify the hostname or IP of the scan engine' },
  );

has_field 'template_id' =>
  (
   type => 'Text',
   label => 'Scan template ID',
   tags => { after_element => \&help,
             help => 'The scan template to use for scanning the clients.' },
  );

has_field 'port' =>
  (
   type => 'PosInteger',
   label => 'Port of the API',
   tags => { after_element => \&help,
             help => 'If you use an alternative port, please specify' },
   default => 3380,
  );

has_field 'template_id' =>
  (
   type => 'Text',
   label => 'Scan template ID',
   tags => { after_element => \&help,
             help => 'The scan template to use for scanning the clients.' },
  );

has_field 'site_id' =>
  (
   type => 'Text',
   label => 'Site ID',
   tags => { after_element => \&help,
             help => 'The identifier of the site to scan (the site where the hosts are located)' },
  );

  has_field 'verify_hostname' =>
  (
   type => 'Toggle',
   label => 'Verify Hostname',
   tags => { after_element => \&help,
             help => 'Verify hostname of server when connecting to the API' },
   checkbox_value  => 'enabled',
   unchecked_value => 'disabled',
   default => 'enabled',
  );

has_block definition =>
  (
   render_list => [ qw(id type username password host port verify_hostname template_id site_id categories oses duration pre_registration registration post_registration) ],
  );

=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
