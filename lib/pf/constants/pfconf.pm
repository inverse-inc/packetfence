package pf::constants::pfconf;

=head1 NAME

pf::constants::pfconf -

=head1 DESCRIPTION

pf::constants::pfconf

=cut

use strict;
use warnings;
our %ALLOWED_SECTIONS = (
    active_active     => undef,
    advanced          => undef,
    alerting          => undef,
    captive_portal    => undef,
    database          => undef,
    database_advanced => undef,
    fencing           => undef,
    general           => undef,
    inline            => undef,
    mse_tab           => undef,
    network           => undef,
    node_import       => undef,
    parking           => undef,
    ports             => undef,
    provisioning      => undef,
    services          => undef,
    snmp_traps        => undef,
    webservices       => undef,
    guests_admin_registration     => undef,
    radius_authentication_methods => undef,
    fingerbank_device_change      => undef,
    radius_configuration => undef,
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;
