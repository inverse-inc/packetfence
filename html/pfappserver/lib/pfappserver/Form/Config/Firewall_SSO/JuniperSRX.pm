package pfappserver::Form::Config::Firewall_SSO::JuniperSRX;

=head1 NAME

pfappserver::Form::Config::Firewall_SSO::JuniperSRX - Web form to add a JuniperSRX firewall

=head1 DESCRIPTION

Form definition to create or update a JuniperSRX firewall.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Firewall_SSO';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use File::Find qw(find);

## Definition
has 'roles' => (is => 'ro', default => sub {[]});

has_field 'id' =>
  (
   type => 'Text',
   label => 'Hostname or IP Address',
   required => 1,
   messages => { required => 'Please specify the hostname or IP of the firewall' },
  );
has_field 'username' =>
  (
   type => 'Text',
   label => 'Username',
   required => 1,
   messages => { required => 'Please specify the username for the Juniper SRX' },
  );
has_field 'password' =>
  (
   type => 'ObfuscatedText',
   label => 'Password',
   required => 1,
   messages => { required => 'You must specify the password' },
  );
has_field 'port' =>
  (
   type => 'Port',
   label => 'Port of the service',
   default => 8443,
   tags => { after_element => \&help,
             help => 'If you use an alternative port, please specify' },
  );
has_field 'type' =>
  (
   type => 'Hidden',
  );

=over

=back

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
