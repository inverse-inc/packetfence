package pf::services::manager::ip6tables;

=head1 NAME

pf::services::manager::ip6tables add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::ip6tables

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw($install_dir $generated_conf_dir);
use pf::log;
use pf::util;
use pf::ip6tables;
use pf::config qw(%Config);

extends 'pf::services::manager';

has '+name' => (default => sub { 'ip6tables' } );

has '+shouldCheckup' => ( default => sub { 1 }  );

has 'runningServices' => (is => 'rw', default => sub { 0 } );

=head2

generateConfig

=cut

sub generateConfig {
    pf::ip6tables::ip6tables_generate_config();
    return 1;
}

=head2 _stop

stop ip6tables (called from systemd)

=cut

sub _stop {
    my ($self) = @_;
    my $logger = get_logger();
    pf::ip6tables::ip6tables_flush_to_default();
    return 1;
}

=head2 isAlive

Check that the monitor is active and a nonempty rules file has been generated.
This does not verify that the rules were successfully loaded into the kernel.

=cut

sub isAlive {
    my ($self) = @_;
    return 0 unless $self->SUPER::isAlive();
    return -s "$generated_conf_dir/ip6tables_generated_rules.conf" ? 1 : 0;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

