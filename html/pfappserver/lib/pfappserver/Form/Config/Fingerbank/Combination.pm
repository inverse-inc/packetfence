package pfappserver::Form::Config::Fingerbank::Combination;

=head1 NAME

pfappserver::Form::Config::Fingerbank::Combination

=head1 DESCRIPTION

Form definition for Fingerbank Combination

=cut

use HTML::FormHandler::Moose;

extends 'pfappserver::Base::Form';

has_field 'id' => (
    type => 'Text',
    label => 'Combination ID',
    readonly => 1,
);

has_field 'dhcp_fingerprint_id' => (
    type => 'Text',
    label => 'DHCP Fingerprint ID',
);

has_field 'dhcp_vendor_id' => (
    type => 'Text',
    label => 'DHCP Vendor ID',
);

has_field 'mac_vendor_id' => (
    type => 'Text',
    label => 'MAC Vendor ID',
);

has_field 'user_agent_id' => (
    type => 'Text',
    label => 'User Agent ID',
);

has_field 'device_id' => (
    type => 'Text',
    label => 'Device ID',
);

has_field 'version' => (
    type => 'Text',
    label => 'Version',
);

has_field 'score' => (
    type => 'Text',
    label => 'Score',
);

has_field created_at => (
    type => 'Uneditable',
);

has_field updated_at => (
    type => 'Uneditable',
);

has_block definition => (
    render_list => [qw(dhcp_fingerprint_id dhcp_vendor_id mac_vendor_id user_agent_id device_id version score created_at updated_at)],
);

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
