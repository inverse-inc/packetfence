package pfappserver::Form::Config::Provisioning::packetfence_ztn;

=head1 NAME

pfappserver::Form::Config::Provisioning::packetfence_ztn

=head1 DESCRIPTION

Web form for the PacketFence Zero Trust provisioner

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Provisioning';
with 'pfappserver::Base::Form::Role::Help';
use pf::provisioner::packetfence_ztn;

my $META = pf::provisioner::packetfence_ztn->meta;

use pf::constants;

has_field 'windows_agent_download_uri' =>
  (
   type => 'Text',
   label => 'Windows agent download URI',
   default => $META->get_attribute('windows_agent_download_uri')->default(),
   required => $TRUE,
  );

has_field 'mac_osx_agent_download_uri' =>
  (
   type => 'Text',
   label => 'Mac OSX agent download URI',
   default => $META->get_attribute('mac_osx_agent_download_uri')->default(),
   required => $TRUE,
  );

has_field 'linux_agent_download_uri' =>
  (
   type => 'Text',
   label => 'Linux agent download URI',
   default => $META->get_attribute('linux_agent_download_uri')->default(),
   required => $TRUE,
  );

has_block definition =>
  (
   render_list => [ qw(id type description category oses windows_agent_download_uri mac_osx_agent_download_uri linux_agent_download_uri) ],
  );

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
