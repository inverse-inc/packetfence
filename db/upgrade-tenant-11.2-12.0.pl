#!/usr/bin/perl

=head1 NAME

to-12-remove-tenant -

=head1 DESCRIPTION

to-12-remove-tenant

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
my $tenant_id = $ENV{PF_TENANT_ID} ||  1;
open(my $fh, ">", "/usr/local/pf/db/upgrade-tenant-11.2-12.0.sql");

my @tenant_tables = qw(
activation
admin_api_audit_log
auth_log
bandwidth_accounting
bandwidth_accounting_history
dns_audit_log
ip4log
ip4log_archive
ip4log_history
ip6log
ip6log_archive
ip6log_history
locationlog
locationlog_history
node
password
person
radacct
radacct_log
radius_audit_log
radius_nas
radreply
scan
security_event
user_preference
);

for my $t (@tenant_tables) {
    print $fh "DELETE FROM $t WHERE tenant_id != $tenant_id;\n";
}

for my $t (qw( bandwidth_accounting bandwidth_accounting_history)) {
    print $fh "UPDATE $t SET node_id = node_id & 0x0000ffffffffffff;\n";
}

close ($fh);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2022 Inverse inc.

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
