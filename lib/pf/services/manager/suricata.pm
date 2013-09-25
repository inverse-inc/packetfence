package pf::services::manager::suricata;
=head1 NAME

pf::services::manager::suricata add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::suricata

=cut

use strict;
use warnings;
use pf::file_paths;
use pf::config;
use Moo;
use pf::services::suricata qw(generate_suricata_conf);
extends 'pf::services::manager';
with 'pf::services::manager::roles::pf_conf_service_managed';

has '+name' => ( default => sub { 'suricata' } );

has '+launcher' => (
    default => sub {
        "%1\$s -D -c $install_dir/var/conf/suricata.yaml -i $monitor_int " .
        "-l $install_dir/var --pidfile $install_dir/var/run/suricata.pid"
    },
);

sub generateConfig {
    generate_suricata_conf();
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

