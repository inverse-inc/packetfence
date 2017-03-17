package pf::services::manager::snort;

=head1 NAME

pf::services::manager::snort add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::snort

=cut

use strict;
use warnings;
use Moo;
extends 'pf::services::manager';
with 'pf::services::manager::roles::pf_conf_trapping_engine';
use pf::file_paths qw(
    $install_dir
    $conf_dir
    $generated_conf_dir
    $var_dir
);
use pf::log;
use pf::constants;
use pf::config qw(
    $monitor_int
    %Config
    $monitor_int
);
use pf::violation_config;
use pf::util qw(parse_template listify);
use pf::config::util;

has '+name' => ( default => sub { 'snort' } );

sub _cmdLine {
    my $self = shift;
    $self->executable
        . " -m 0137 -c $generated_conf_dir/snort.conf -i $monitor_int " . "-N -l $install_dir/var ";
}

sub generateConfig {
    my $logger = get_logger();
    my %tags;
    $tags{'template'}      = "$conf_dir/snort.conf";
    $tags{'trapping-range'} = $Config{'trapping'}{'range'};
    my $dhcp_servers = $Config{'general'}{'dhcpservers'} || [];
    $tags{'dhcp_servers'} = join(",", @{ listify $dhcp_servers });
    $tags{'install_dir'}   = $install_dir;
    my @rules;

    if (exists $pf::violation_config::Violation_Config{'defaults'}{'snort_rules'}) {
        foreach my $rule ( split( /\s*,\s*/, $pf::violation_config::Violation_Config{'defaults'}{'snort_rules'} ) ) {
            if ( $rule !~ /^\// && -e "$install_dir/conf/snort/$rule" || -e $rule ) {
                # Append configuration directory if the path doesn't start with /
                $rule = "\$RULE_PATH/$rule" if ( $rule !~ /^\// );
                push @rules, "include $rule";
            }
            else {
                $logger->warn("Snort rules definition file $rule was not found.");
            }
        }
    }
    $tags{'snort_rules'} = join( "\n", @rules );
    $logger->info("generating $conf_dir/snort.conf");
    parse_template( \%tags, "$conf_dir/snort.conf", "$generated_conf_dir/snort.conf" );
    return $TRUE;
}

sub pidFile {
    my ($self) = @_;
    my $name = $self->name;
    return "$var_dir/run/${name}_${monitor_int}.pid";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

