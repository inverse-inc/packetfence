#!/usr/bin/perl

=head1 NAME

to-12.1-move-rolebyname-to-vpnbyname-fortigate.pl

=cut

=head1 DESCRIPTION

Move role by name to role by vpn

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $switches_config_file
);
use pf::util;

run_as_pf();

my $file = $switches_config_file;

my $cs = pf::IniFiles->new(-file => $file, -allowempty => 1);

tie my %switches_conf_file, 'pf::IniFiles', ( -file => $pf::file_paths::switches_config_file );



foreach my $key (keys %switches_conf_file) {
    if (defined($switches_conf_file{$key}{'type'}) && $switches_conf_file{$key}{'type'} eq 'Fortinet::FortiGate') {
        foreach my $role (keys %{$switches_conf_file{$key}}) {
            if ($role =~ /(.*)Role$/) {
                if (!$cs->exists($key, $1."Vpn")) {
                    $cs->newval($key, $1."Vpn", $switches_conf_file{$key}{$role});
                }
            }
        }
    }
}


$cs->RewriteConfig();

print "All done\n";

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

