package pfappserver::Form::Config::Network;

=head1 NAME

pfappserver::Form::Interface - Web form for a network

=head1 DESCRIPTION

Form definition to update a default network.

=cut

use pf::util;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';
with 'pfappserver::Form::Widget::Theme::Pf';

has '+field_name_space' => ( default => 'pfappserver::Form::Field' );
has '+widget_name_space' => ( default => 'pfappserver::Form::Widget' );
has '+language_handle' => ( builder => 'get_language_handle_from_ctx' );

has 'network' => ( is => 'ro' );

has_field 'dhcp_start' =>
  (
   type => 'IPAddress',
   label => 'Starting IP Address',
   required => 1,
   messages => { required => 'Please specify the starting IP address of the DHCP scope.' },
  );
has_field 'dhcp_end' =>
  (
   type => 'IPAddress',
   label => 'Ending IP Address',
   required => 1,
   messages => { required => 'Please specify the ending IP address of the DHCP scope.' },
  );
has_field 'dhcp_default_lease_time' =>
  (
   type => 'PosInteger',
   label => 'Default Lease Time',
   required => 1,
   messages => { required => 'Please specify the default DHCP lease time.' },
  );
has_field 'dhcp_max_lease_time' =>
  (
   type => 'PosInteger',
   label => 'Max Lease Time',
   required => 1,
   messages => { required => 'Please specify the maximum DHCP lease time.' },
  );

=head2 validate

Make sure the ending DHCP IP address is after the starting DHCP IP address.

Make sure the max lease time is higher than the default lease time.

=cut

sub validate {
    my $self = shift;

    if (ip2int($self->value->{dhcp_start}) >= ip2int($self->value->{dhcp_end})) {
        $self->field('dhcp_end')->add_error('The ending DHCP address must be greater than the starting DHCP address.');
    }
    if ($self->value->{dhcp_default_lease_time} > $self->value->{dhcp_max_lease_time}) {
        $self->field('dhcp_max_lease_time')->add_error('The maximum lease time must be greater than the default lease time.');
    }
}

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

__PACKAGE__->meta->make_immutable;
1;
