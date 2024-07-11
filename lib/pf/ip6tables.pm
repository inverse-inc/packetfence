package pf::ip6tables;

=head1 NAME

pf::ip6tables - module for ip6tables rules management.

=cut

=head1 DESCRIPTION

pf::ip6tables contains the functions necessary to manipulate the ip6tables service

=head1 CONFIGURATION AND ENVIRONMENT

F<pf.conf> configuration file and ip6tables template F<ip6tables.conf>.

=cut

use strict;
use warnings;

use pf::log;
use Readonly;
use pf::constants;
use File::Slurp qw(read_file);
use pf::util;

use pf::config qw(
    $management_network
    @portal_ints
);
use pf::file_paths qw($generated_conf_dir $conf_dir);

# This is the content that needs to match in the iptable rules for the service
# to be considered as running
Readonly our $FW_FILTER_INPUT_MGMT      => 'input-v6-management-if';
Readonly our $FW_FILTER_INPUT_PORTAL    => 'input-v6-portal-if';

sub generate {
    my ($class) = @_;
    my $logger = get_logger();
    my %tags;
    $tags{'input_management_include'} = "#BEGIN include ip6tables-input-management.conf.inc\n" . read_file("$conf_dir/ip6tables-input-management.conf.inc") . "#END include ip6tables-input-management.conf.inc\n";

    $tags{management_chain} = <<EOF;
-N $FW_FILTER_INPUT_MGMT
-A INPUT -i $management_network->{Tint} -j $FW_FILTER_INPUT_MGMT
EOF

    $tags{portal_chain} = "-N $FW_FILTER_INPUT_PORTAL\n";
    foreach my $portal_interface ( @portal_ints ) {
        $tags{portal_chain} .= <<EOF;
-A INPUT -i $portal_interface->{Tint} -j $FW_FILTER_INPUT_PORTAL
EOF
    }

    parse_template( \%tags, "$conf_dir/ip6tables.conf", "$generated_conf_dir/ip6tables.conf" );
    $class->restore("$generated_conf_dir/ip6tables.conf");
}


sub save {
    my ($class, $save_file) = @_;
    my $logger = get_logger();
    $logger->info( "saving existing ip6tables to " . $save_file );
    safe_pf_run("/usr/sbin/ip6tables-save", '-t', 'nat', { stdout => $save_file});
    safe_pf_run("/usr/sbin/ip6tables-save", '-t', 'mangle', { stdout => $save_file, stdout_append => 1});
    safe_pf_run("/usr/sbin/ip6tables-save", '-t', 'filter', { stdout => $save_file, stdout_append => 1});
}

sub restore {
    my ($class, $restore_file) = @_;
    my $logger = get_logger();
    if ( -r $restore_file ) {
        $logger->info( "restoring ip6tables from " . $restore_file );
        safe_pf_run("/usr/sbin/ip6tables-restore", { stdin => $restore_file });
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
USA.

=cut

1;
