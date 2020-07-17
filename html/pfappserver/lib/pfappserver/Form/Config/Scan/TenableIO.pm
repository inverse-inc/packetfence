package pfappserver::Form::Config::Scan::TenableIO;

=head1 NAME

pfappserver::Form::Config::Scan::TenableIO - Web form to add a TenableIO Scan Engine

=head1 DESCRIPTION

Form definition to create or update a TenableIO Scan Engine.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Scan';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use File::Find qw(find);

has_field 'url' =>
  (
   type => 'Text',
   label => 'TenableIO url',
   default => 'cloud.tenable.com',
   required => 1,
   messages => { required => 'Please specify the url of the TenableIO' },
  );

has_field 'accessKey' =>
  (
   type => 'Text',
   label => 'Access KEY',
   tags => { after_element => \&help,
             help => 'Define the access key' },
  );

has_field 'secretKey' =>
  (
   type => 'Text',
   label => 'Secret KEY',
   tags => { after_element => \&help,
             help => 'Define the secret key' },
  );

has_field 'type' =>
  (
   type => 'Hidden',
   default => 'tenableio',
  );

has_field 'folderId' =>
  (
   type => 'Text',
   label => 'Folder ID',
   default => '162',
   tags => { after_element => \&help,
             help => 'Define the Folder ID' },
  );

has_block definition =>
  (
   render_list => [ qw(id url accessKey secretKey type folderId tenableio_clientpolicy scannername categories oses duration pre_registration registration post_registration) ],
  );

has_field 'tenableio_clientpolicy' =>
  (
   type => 'Text',
   label => 'TenableIO client policy',
   tags => { after_element => \&help,
             help => 'Name of the client policy to use on tenableIO' },
  );

has_field 'scannername' =>
  (
   type => 'Text',
   label => 'TenableIO scanner template',
   default => 'Local Scanner',
   tags => { after_element => \&help,
             help => 'Name of the scanner template to use on the tenableIO' },
  );

=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
