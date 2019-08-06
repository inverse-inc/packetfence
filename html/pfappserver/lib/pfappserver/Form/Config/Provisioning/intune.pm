package pfappserver::Form::Config::Provisioning::intune;

=head1 NAME

pfappserver::Form::Config::Provisioning - Web form for a switch

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Provisioning';
with 'pfappserver::Base::Form::Role::Help';

has_field 'tenantID' =>
  (
   type => 'Text',
   label => 'Tenant ID',
   required => 1,
  );

has_field 'applicationID' =>
  (
   type => 'Text',
   label => 'ApplicationID',
   required => 1,
  );


has_field 'applicationSecret' =>
  (
   type => 'Text',
   label => 'Application Secret',
   required => 1,
  );

has_field 'loginUrl' =>
  (
   type => 'Text',
   default => 'login.microsoftonline.com',
  );

has_field 'host' =>
  (
   type => 'Text',
   default => 'graph.microsoft.com',
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
   required => 0,
  );

has_field 'windows_agent_download_uri' =>
  (
   type => 'Text',
   required => 1,
   default => 'https://www.microsoft.com/en-us/p/company-portal/9wzdncrfj3pz',
  );

has_field 'mac_osx_agent_download_uri' =>
  (
   type => 'Text',
   required => 1,
   default => 'https://portal.manage.microsoft.com',
  );

has_field 'ios_agent_download_uri' =>
  (
   type => 'Text',
   required => 1,
   default => 'https://apps.apple.com/us/app/intune-company-portal/id719171358',
  );

has_field 'android_agent_download_uri' =>
  (
   type => 'Text',
   required => 1,
   default => 'https://play.google.com/store/apps/details?id=com.microsoft.windowsintune.companyportal&hl=en_US',
  );

has_field 'domains' =>
  (
   type => 'Text',
   label => 'Authorized domains',
   required => 1,
   default => 'play.google.com,portal.manage.microsoft.com,apps.apple.com,docs.microsoft.com',
   element_attr => {'placeholder' => 'play.google.com,portal.manage.microsoft.com,apps.apple.com'},
   element_class => ['input-xlarge'],
   tags => { after_element => \&help,
             help => 'Comma-separated list of domains that will be resolved with the correct IP addresses.' },
  );

has_block definition =>
  (
   render_list => [ qw(id type description category oses tenantID applicationID applicationSecret loginUrl host port protocol access_token windows_agent_download_uri mac_osx_agent_download_uri ios_agent_download_uri android_agent_download_uri domains) ],
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
