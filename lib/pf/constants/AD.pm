package pf::constants::AD;

=head1 NAME

pf::constants::AD - Constants for Active directroy

=cut

=head1 DESCRIPTION

pf::constants::AD

Constants for Active directory

=cut

use strict;
use warnings;

# UserAccountControl attributes
# These values were gotten from https://support.microsoft.com/en-ca/kb/305144
#

our $AD_SCRIPT                         = 0x0001;
our $AD_ACCOUNTDISABLE                 = 0x0002;
our $AD_HOMEDIR_REQUIRED               = 0x0008;
our $AD_LOCKOUT                        = 0x0010;
our $AD_PASSWD_NOTREQD                 = 0x0020;
our $AD_PASSWD_CANT_CHANGE             = 0x0040; # Note You cannot assign this permission by directly modifying the UserAccountControl attribute.
                                                 # For information about how to set the permission programmatically, see https://msdn.microsoft.com/en-us/library/aa746398.aspx
our $AD_ENCRYPTED_TEXT_PWD_ALLOWED     = 0x0080;
our $AD_TEMP_DUPLICATE_ACCOUNT         = 0x0100;
our $AD_NORMAL_ACCOUNT                 = 0x0200;
our $AD_INTERDOMAIN_TRUST_ACCOUNT      = 0x0800;
our $AD_WORKSTATION_TRUST_ACCOUNT      = 0x1000;
our $AD_SERVER_TRUST_ACCOUNT           = 0x2000;
our $AD_DONT_EXPIRE_PASSWORD           = 0x10000;
our $AD_MNS_LOGON_ACCOUNT              = 0x20000;
our $AD_SMARTCARD_REQUIRED             = 0x40000;
our $AD_TRUSTED_FOR_DELEGATION         = 0x80000;
our $AD_NOT_DELEGATED                  = 0x100000;
our $AD_USE_DES_KEY_ONLY               = 0x200000;
our $AD_DONT_REQ_PREAUTH               = 0x400000;
our $AD_PASSWORD_EXPIRED               = 0x800000;
our $AD_TRUSTED_TO_AUTH_FOR_DELEGATION = 0x1000000;
our $AD_PARTIAL_SECRETS_ACCOUNT        = 0x04000000;


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
