package pfappserver::Form::Config::Fingerbank::DHCP6_Enterprise;

=head1 NAME

pfappserver::Form::Config::Fingerbank::DHCP6_Enterprise

=head1 DESCRIPTION

Web form for Fingerbank DHCPv6 Enterprise

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';


## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'ID',
   readonly => 1,
  );

has_field 'value' =>
  (
   type => 'Text',
   label => 'Value',
   required => 1,
  );

has_field 'organization' =>
  (
   type => 'Text',
   label => 'DHCPv6 Enterprise Organization',
  );

has_field created_at =>
  (
  type => 'Uneditable',
  );

has_field updated_at =>
  (
  type => 'Uneditable',
  );

has_block definition =>
  (
    render_list => [qw(value created_at updated_at)],
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
