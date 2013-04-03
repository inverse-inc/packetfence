package pf::services::snort;

=head1 NAME

pf::services::snort - helper configuration module for supported snortd

=head1 DESCRIPTION

This module contains some functions that generates snortd configuration
according to what PacketFence needs to accomplish.

=head1 CONFIGURATION AND ENVIRONMENT

Read the following configuration files: F<conf/snort.conf>.

Generates the following configuration files: F<var/conf/snort.conf>.

=cut

use strict;
use warnings;

use Log::Log4perl;
use POSIX;
use Readonly;

use pf::config;
use pf::config::cached;
use pf::util qw(get_all_internal_ips parse_template);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(generate_snort_conf);
}

=head1 SUBROUTINES

=over

=item * generate_snort_conf

=cut

sub generate_snort_conf {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my %tags;
    $tags{'template'}      = "$conf_dir/snort.conf";
    $tags{'trapping-range'} = $Config{'trapping'}{'range'};
    $tags{'dhcp_servers'}  = $Config{'general'}{'dhcpservers'};
    $tags{'dns_servers'}   = $Config{'general'}{'dnsservers'};
    $tags{'install_dir'}   = $install_dir;
    my %violations_conf;
    tie %violations_conf, 'pf::config::cached', ( -file => "$conf_dir/violations.conf" );
    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        $logger->error( "Error reading violations.conf: " . join( "\n", @errors ) . "\n" );
        return;
    }

    my @rules;

    foreach my $rule ( split( /\s*,\s*/, $violations_conf{'defaults'}{'snort_rules'} ) ) {

        #append install_dir if the path doesn't start with /
        $rule = "\$RULE_PATH/$rule" if ( $rule !~ /^\// );
        push @rules, "include $rule";
    }
    $tags{'snort_rules'} = join( "\n", @rules );
    $logger->info("generating $conf_dir/snort.conf");
    parse_template( \%tags, "$conf_dir/snort.conf", "$generated_conf_dir/snort.conf" );
    return $TRUE;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
