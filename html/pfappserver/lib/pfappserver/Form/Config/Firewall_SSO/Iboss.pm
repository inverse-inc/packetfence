package pfappserver::Form::Config::Firewall_SSO::Iboss;

=head1 NAME

pfappserver::Form::Config::Firewall_SSO::Iboss - Web form for a Iboss device

=head1 DESCRIPTION

Form definition to create or update an Iboss device.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Firewall_SSO';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use File::Find qw(find);

has_field '+password' =>
  (
   default => 'XS832CF2A',
   tags => { after_element => \&help,
             help => 'Change the default key if necessary' },
  );
has_field '+port' =>
  (
    default => 8015,
  );
has_field 'nac_name' =>
  (
   type => 'Text',
   label => 'NAC Name',
   tags => { after_element => \&help,
             help => 'Should match the NAC name from the Iboss configuration' },
    default => 'PacketFence',
  );
has_field 'type' =>
  (
   type => 'Hidden',
  );

has_block definition =>
  (
   render_list => [ qw(id type password port nac_name categories networks cache_updates cache_timeout username_format default_realm) ],
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
