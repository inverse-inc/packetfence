package pfappserver::Form::Config::Mfa::Akamai;

=head1 NAME

pfappserver::Form::Config::Mfa::Akamai - Web form to add a Akamai MFA

=head1 DESCRIPTION

Form definition to create or update a Akamai MFA.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Mfa';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use File::Find qw(find);

has_field 'app_id' =>
  (
   type => 'Text',
   label => 'Application ID',
   required => 1,
   messages => { required => 'Please specify the Application ID' },
  );

has_field 'app_secret' =>
  (
   type => 'ObfuscatedText',
   label => 'Application Secret',
   required => 1,
   messages => { required => 'Please specify the application secret' },
  );

has_field 'radius_mfa_method' =>
  (
   type => 'Select',
   label => 'type',
   required => 1,
   options =>
   [
    { value => 'push', label => 'Push' },
    { value => 'strip-otp', label => 'Strip OTP' },
   ],
   default => 'push',
   tags => { after_element => \&help,
             help => 'RADIUS MFA method' },
  );

has_field 'type' =>
  (
   type => 'Hidden',
   default => 'Akamai',
  );

has_block definition =>
  (
   render_list => [ qw(id app_id app_secret radius_mfa_method) ],
  );

=over

=back

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;
