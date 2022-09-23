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

has_field 'eduroam_options' =>
  (
   type => 'TextArea',
   label => 'Eduroam Realm Options',
   required => 0,
   default => 'nostrip',
  );

has_field 'eduroam_radius_auth' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Eduroam RADIUS AUTH',
   options_method => \&options_radius,
   element_class => ['chzn-select'],
   element_attr => {'data-placeholder' => 'Click to select a RADIUS Server'},
  );

has_field 'eduroam_radius_auth_proxy_type' =>
  (
   type => 'Select',
   label => 'type',
   required => 1,
   options =>
   [
    { value => 'keyed-balance', label => 'Keyed Balance' },
    { value => 'fail-over', label => 'Fail Over' },
    { value => 'load-balance', label => 'Load Balance' },
    { value => 'client-balance', label => 'Client Balance' },
    { value => 'client-port-balance', label => 'Client Port Balance' },
   ],
   default => 'keyed-balance',
  );

has_field 'auth_listening_port' => (
    type            => 'Port',
    label           => 'Authentication listening port',
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
   default => '',
  );

has_field 'monitor',
  (
   type => 'Toggle',
   label => 'Monitor',
   checkbox_value => '1',
   unchecked_value => '0',
   default => pf::Authentication::Source::EduroamSource->meta->get_attribute('monitor')->default,
  );

has_field 'eduroam_operator_name' =>
  (
   type => 'Text',
   required => 0,
   default => '',
   element_class => ['span10'],
  );

sub options_realm {
    my $self = shift;
    my @roles = map { $_ => $_ } sort keys %pf::config::ConfigRealm;
    return @roles;
}

=head2 options_radius

=cut

sub options_radius {
    my $self = shift;
    my @radius = map { $_ => $_ } keys %pf::config::ConfigAuthenticationRadius;
    return @radius;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2022 Inverse inc.

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

