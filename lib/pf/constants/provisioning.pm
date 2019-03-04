package pf::constants::provisioning;

=head1 NAME

pf::constants::provisioning

=cut

=head1 DESCRIPTION

pf::constants::provisioning - Constants for provisioner modules

=cut

use base qw(Exporter);
our @EXPORT_OK = qw(
    $SENTINEL_ONE_TOKEN_EXPIRY
    $NOT_COMPLIANT_FLAG
);

use Readonly;

=item $SENTINEL_ONE_TOKEN_EXPIRY

Amount of seconds a Sentinel one token is valid (1 hour)

=cut

Readonly our $SENTINEL_ONE_TOKEN_EXPIRY => 60*60;

=item $NOT_COMPLIANT_FLAG

The flag that defines a non-compliant device as returned by the MDM filters

=cut

Readonly our $NOT_COMPLIANT_FLAG => "non-compliant";

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
