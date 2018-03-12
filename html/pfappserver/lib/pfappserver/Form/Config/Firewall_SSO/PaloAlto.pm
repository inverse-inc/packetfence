package pfappserver::Form::Config::Firewall_SSO::PaloAlto;

=head1 NAME

pfappserver::Form::Config::Firewall_SSO::PaloAlto - Web form for a floating device

=head1 DESCRIPTION

Form definition to create or update a floating network device.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Firewall_SSO';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use File::Find qw(find);
use pf::constants::firewallsso qw($SYSLOG_TRANSPORT $HTTP_TRANSPORT);

has_field 'transport' =>
  (
   type => 'Select',
   options => [{ label => 'Syslog', value => $SYSLOG_TRANSPORT }, { label => 'HTTP' , value => $HTTP_TRANSPORT }],
   default => $HTTP_TRANSPORT,
  );

has_field '+password' =>
  (
   type => 'ObfuscatedText',
   label => 'Secret or Key',
   tags => { after_element => \&help,
             help => 'If using the HTTP transport, specify the password for the Palo Alto API' },
   required => 0,
  );

has_field '+port' =>
  (
   tags => { after_element => \&help,
             help => 'If you use an alternative port, please specify. This parameter is ignored when the Syslog transport is selected.' },
    default => 443,
  );

has_field 'type' =>
  (
   type => 'Hidden',
  );

has_field 'vsys' =>
  (
   type => 'PosInteger',
   label => 'Vsys ',
    tags => { after_element => \&help,
             help => 'Please define the Virtual System number. This only has an effect when used with the HTTP transport.' },
   default => 1,
  );

has_block definition =>
  (
   render_list => [ qw(id type vsys transport port password categories networks cache_updates cache_timeout username_format default_realm) ],
  );

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
