package pf::constants::saml;

=head1 NAME

pf::constants::saml

=cut

=head1 DESCRIPTION

Constants for SAML.
This module was created as a bridge between Lasso::Constants and PacketFence. Given we have made Lasso a conditional runtime use, constants the way they were defined in Lasso didn't work. This module is there to allow to 'require' Lasso while being able to use its constants by requiring this module.

Important note: This is a hack.

=cut

use strict;
use warnings;
use Lasso;

our $PROVIDER_ROLE_IDP = Lasso::Constants::PROVIDER_ROLE_IDP;
our $HTTP_METHOD_REDIRECT = Lasso::Constants::HTTP_METHOD_REDIRECT;
our $SAML2_NAME_IDENTIFIER_FORMAT_PERSISTENT = Lasso::Constants::SAML2_NAME_IDENTIFIER_FORMAT_PERSISTENT;
our $SAML2_METADATA_BINDING_ARTIFACT = Lasso::Constants::SAML2_METADATA_BINDING_ARTIFACT;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

