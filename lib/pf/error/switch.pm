package pf::error::switch;

=head1 NAME

pf::error::switch -

=head1 DESCRIPTION

pf::error::switch

=cut

use strict;
use warnings;

our $ACLsLimitErrMsg = 'ACLs limit reached for switch';
our $DownloadACLsErrMsg = 'Downloadable ACLs limit reached for switch';
our $ACLsNotSupportedMsg = 'ACLs not supported for switch';
our $DownloadACLsLimitErrCode = 10001;
our $ACLsLimitErrCode = 10002;
our $ACLsNotSupportedErrCode = 10003;

our %MESSAGES = (
   $DownloadACLsLimitErrCode => $DownloadACLsErrMsg,
   $ACLsLimitErrCode => $ACLsLimitErrMsg,
   $ACLsNotSupportedErrCode => $ACLsNotSupportedMsg,
);

sub makeACLsError {
    my ($switch, $role, $code) = @_;
    return { code => $code, role_name => $role, message => $MESSAGES{$code}, switch_id => $switch->{_id} };
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;
