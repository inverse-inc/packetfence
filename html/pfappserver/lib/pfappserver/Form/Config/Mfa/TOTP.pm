package pfappserver::Form::Config::Mfa::TOTP;

=head1 NAME

pfappserver::Form::Config::Mfa::TOTP - Web form to add a TOTP MFA

=head1 DESCRIPTION

Form definition to create or update a TOTP MFA.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Mfa';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use File::Find qw(find);

has_field 'scope' =>
   (
    type => 'Hidden',
    default => 'Radius,Portal',
   );

has_field 'type' =>
  (
   type => 'Hidden',
   default => 'TOTP',
  );

has_field 'radius_mfa_method' =>
  (
   type => 'Select',
   required => 1,
   options =>
   [
    { value => 'strip-otp', label => 'Strip OTP' },
    { value => 'second-password', label => 'Second Password Field' },
   ],
   default => 'strip-otp',
  );

has_block definition =>
  (
   render_list => [ qw(id radius_mfa_method) ],
  );

=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
