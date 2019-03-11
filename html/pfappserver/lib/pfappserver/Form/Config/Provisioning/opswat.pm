package pfappserver::Form::Config::Provisioning::opswat;

=head1 NAME

pfappserver::Form::Config::Provisioning - Web form for a switch

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Provisioning';
with 'pfappserver::Base::Form::Role::Help';

has_field 'client_id' =>
  (
   type => 'Text',
   label => 'Client Key',
   required => 1,
  );

has_field 'client_secret' =>
  (
   type => 'Text',
   label => 'Client Secret',
   required => 1,
  );

has_field 'host' =>
  (
   type => 'Text',
   default => 'gears.opswat.com',
  );

has_field 'port' =>
  (
   type => 'Port',
   required => 1,
   default => 443,
  );

has_field 'protocol' =>
  (
   type => 'Select',
   options => [{ label => 'http', value => 'http' }, { label => 'https' , value => 'https' }],
   default => 'https',
  );

has_field 'access_token' =>
  (
   type => 'Text',
   required => 1,
  );

has_field 'refresh_token' =>
  (
   type => 'Text',
   required => 1,
  );

has_field 'agent_download_uri' =>
  (
   type => 'Text',
   required => 1,
  );

has_field 'critical_issues_threshold' =>
  (
   type => 'PosInteger',
   default => 0,
   tags => { after_element => \&help,
             help => 'Raise the non compliance security event the number of critical issues is greater or equal than this. 0 deactivates it' },
  );

has_block definition =>
  (
   render_list => [ qw(id type description category oses client_id client_secret host port protocol access_token refresh_token agent_download_uri) ],
  );

has_block compliance =>
  (
   render_list => [ qw(non_compliance_security_event critical_issues_threshold) ]
  );

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;
