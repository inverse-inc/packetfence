package pfappserver::Form::Config::Source::RADIUS;

=head1 NAME

pfappserver::Form::Config::Source::RADIUS - Web form for a RADIUS user source

=head1 DESCRIPTION

Form definition to create or update a RADIUS user source.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Source';
with 'pfappserver::Base::Form::Role::Help', 'pfappserver::Base::Form::Role::InternalSource';

# Form fields
has_field 'host' =>
  (
   type => 'Text',
   label => 'Host',
   element_class => ['input-small'],
   element_attr => {'placeholder' => '127.0.0.1'},
   default => '127.0.0.1',
   required => 1,
  );
has_field 'port' =>
  (
   type => 'PosInteger',
   label => 'Port',
   element_class => ['input-mini'],
   element_attr => {'placeholder' => '1812'},
   default => 1812,
   required => 1,
   tags => { after_element => \&help,
             help => 'If you use this source in the realm configuration the accounting port will be this port + 1' },
  );
has_field 'secret' =>
  (
   type => 'ObfuscatedText',
   label => 'Secret',
   required => 1,
   # Default value needed for creating dummy source
   default => '',
  );
has_field 'timeout' =>
  (
   type => 'PosInteger',
   label => 'Timeout',
   required => 1,
   element_class => ['input-mini'],
   element_attr => {'placeholder' => '1'},
   default => 1,
  );
has_field 'monitor',
  (
   type => 'Toggle',
   label => 'Monitor',
   checkbox_value => '1',
   unchecked_value => '0',
   tags => { after_element => \&help,
             help => 'Do you want to monitor this source?' },
   default => pf::Authentication::Source::RADIUSSource->meta->get_attribute('monitor')->default,
);
has_field 'options',
  (
   type => 'TextArea',
   label => 'Options',
   tags => { after_element => \&help,
             help => 'Define options for FreeRADIUS home_server definition (if you use the source in the realm configuration). Need a radius restart.' },
   default => 'type = auth+acct',
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
