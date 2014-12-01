package pf::services::manager::pfclustermgmt;
=head1 NAME

pf::services::manager::pfclustermgmt add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::pfclustermgmt

=cut

use strict;
use warnings;
use Moo;
use IPC::Cmd qw[can_run run];
use List::MoreUtils qw(uniq);
use POSIX;
use pf::config;
use pf::log;
use pf::util;

extends 'pf::services::manager';
with 'pf::services::manager::roles::is_managed_vlan_inline_enforcement';

has '+name' => (default => sub { 'pfclustermgmt' } );

has '+launcher' => (default => sub { "sudo %1\$s -d" } );

#has '+shouldCheckup' => ( default => sub { 0 }  );

sub isManaged {
    my ($self) = @_;
    my @ints = uniq(@listen_ints,@dhcplistener_ints);
    foreach my $interface ( @ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        if (isenabled($cfg->{'active_active_enabled'})) {
            return 1;
        }
    }
    return 0;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>



=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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
