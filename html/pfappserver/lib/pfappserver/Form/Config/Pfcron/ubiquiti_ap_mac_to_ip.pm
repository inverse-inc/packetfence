package pfappserver::Form::Config::Pfcron::ubiquiti_ap_mac_to_ip;

=head1 NAME

pfappserver::Form::Config::Pfcron::ubiquiti_ap_mac_to_ip

=head1 DESCRIPTION

Web form for ubiquiti_ap_mac_to_ip pfcron task

=cut

use HTML::FormHandler::Moose;

use pfappserver::Form::Config::Pfcron qw(default_field_method);

extends 'pfappserver::Form::Config::Pfcron';
with 'pfappserver::Base::Form::Role::Help';

has_block definition => (
    render_list => [qw(type status interval)],
);


=head2 default_type

default value of type

=cut

sub default_type {
    return "ubiquiti_ap_mac_to_ip";
}


=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
