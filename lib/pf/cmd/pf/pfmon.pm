package pf::cmd::pf::pfmon;

=head1 NAME

pf::cmd::pf::pfmon -

=head1 SYNOPSIS

pfcmd pfmon <task> [options...]


=head2 tasks

=over

=item acct_cleanup

=item acct_maintenance

=item auth_log_cleanup

=item certificates_check

=item pki_certificates_check

=item cleanup_chi_database_cache

=item cluster_check

=item fingerbank_data_update

=item ip4log_cleanup

=item ip6log_cleanup

=item locationlog_cleanup

=item node_cleanup

=item nodes_maintenance

=item option82_query

=item password_of_the_day

=item person_cleanup

=item provisioning_compliance_poll

=item radius_audit_log_cleanup

=item dns_audit_log_cleanup

=item security_event_maintenance

=item switch_cache_lldpLocalPort_description

=back

=head1 DESCRIPTION

pf::cmd::pf::pfmon

=cut

use strict;
use warnings;
use base qw(pf::cmd::pf::pfcron);

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
