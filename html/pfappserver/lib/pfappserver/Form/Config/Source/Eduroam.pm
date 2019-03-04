package pfappserver::Form::Config::Source::Eduroam;

=head1 NAME

pfappserver::Form::Config::Source::Eduroam

=cut

=head1 DESCRIPTION

Form definition to create or update an Eduroam authentication source.

=cut

use strict;
use warnings;

use pf::config qw( %Config );

use HTML::FormHandler::Moose;

extends 'pfappserver::Form::Config::Source';
with 'pfappserver::Base::Form::Role::Help';

has_field 'server1_address' => (
    type        => 'Text',
    label       => 'Server 1 address',
    required    => 1,
    # Default value needed for creating dummy source
    default     => "",
    tags        => {
        after_element   => \&help,
        help            => 'Eduroam server 1 address',
    },
);

has_field 'server1_port' => (
    type            => 'PosInteger',
    label           => 'Eduroam server 1 port',
    element_attr    => {
        placeholder     => pf::Authentication::Source::EduroamSource->meta->get_attribute('server1_port')->default,
    },
    default         => pf::Authentication::Source::EduroamSource->meta->get_attribute('server1_port')->default,
);

has_field 'server2_address' => (
    type        => 'Text',
    label       => 'Server 2 address',
    required    => 1,
    # Default value needed for creating dummy source
    default     => "",
    tags        => {
        after_element   => \&help,
        help            => 'Eduroam server 2 address',
    },
);

has_field 'server2_port' => (
    type            => 'PosInteger',
    label           => 'Eduroam server 2 port',
    element_attr    => {
        placeholder     => pf::Authentication::Source::EduroamSource->meta->get_attribute('server2_port')->default,
    },
    default         => pf::Authentication::Source::EduroamSource->meta->get_attribute('server2_port')->default,
);

has_field 'radius_secret' => (
    type        => 'Text',
    label       => 'RADIUS secret',
    required    => 1,
    # Default value needed for creating dummy source
    default     => "",
    tags        => {
        after_element   => \&help,
        help            => 'Eduroam RADIUS secret',
    },
);

has_field 'auth_listening_port' => (
    type            => 'PosInteger',
    label           => 'Authentication listening port',
    tags            => {
        after_element   => \&help,
        help            => 'PacketFence Eduroam RADIUS virtual server authentication listening port',
    },
    element_attr    => {
        placeholder     => pf::Authentication::Source::EduroamSource->meta->get_attribute('auth_listening_port')->default,
    },
    default         => pf::Authentication::Source::EduroamSource->meta->get_attribute('auth_listening_port')->default,
);


has_field 'reject_realm' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Reject Realms',
   options_method => \&options_realm,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a realm'},
   tags => { after_element => \&help,
             help => 'Realms that will be rejected' },
   default => '',
  );

has_field 'local_realm' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Local Realms',
   options_method => \&options_realm,
   element_class => ['chzn-deselect'],
   element_attr => {'data-placeholder' => 'Click to add a realm'},
   tags => { after_element => \&help,
             help => 'Realms that will be authenticate locally' },
   default => '',
  );

has_field 'monitor',
  (
   type => 'Toggle',
   label => 'Monitor',
   checkbox_value => '1',
   unchecked_value => '0',
   tags => { after_element => \&help,
             help => 'Do you want to monitor this source?' },
   default => pf::Authentication::Source::EduroamSource->meta->get_attribute('monitor')->default,
);

sub options_realm {
    my $self = shift;
    my @roles = map { $_ => $_ } sort keys %pf::config::ConfigRealm;
    return @roles;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;

