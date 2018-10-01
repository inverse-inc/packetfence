package pf::Authentication::CreateLocalAccountRole;

=head1 NAME

pf::Authentication::CreateLocalAccountRole

=head1 DESCRIPTION

Role that defines the Authentication source behavior for creating local accounts

=cut

use Moose::Role;
use pf::Authentication::constants qw($LOCAL_ACCOUNT_UNLIMITED_LOGINS);
use pf::ConfigStore::Pf;

has 'create_local_account' => (isa => 'Str', is => 'rw', default => 'no');
has 'local_account_logins' => (isa => 'Str', is => 'rw', default => $LOCAL_ACCOUNT_UNLIMITED_LOGINS);
has 'hash_passwords'       => (isa => 'Maybe[Str]', is => 'rw', default => pf::ConfigStore::Pf->new->read("advanced")->{"hash_passwords"});
has 'password_length'      => (isa => 'Maybe[Int]', is => 'rw', default => 8);

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
