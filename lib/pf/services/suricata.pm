package pf::services::suricata;

=head1 NAME

pf::services::suricata - helper configuration module for supported suricata IDS

=head1 DESCRIPTION

This module contains some functions that generates suricata configuration
according to what PacketFence needs to accomplish.

=head1 CONFIGURATION AND ENVIRONMENT

Read the following configuration files: F<conf/suricata.yaml>.

Generates the following configuration files: F<var/conf/suricata.yaml>.

=cut

use strict;
use warnings;

use Log::Log4perl;
use POSIX;
use Readonly;

use pf::config;
use pf::violation_config;
use pf::util qw(parse_template);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT_OK );
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(generate_suricata_conf);
}

=head1 SUBROUTINES

=over

=item * generate_suricata_conf

=cut

sub generate_suricata_conf {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my %tags;
    $tags{'template'}      = "$conf_dir/suricata.yaml";
    $tags{'trapping-range'} = $Config{'trapping'}{'range'};
    $tags{'install_dir'}   = $install_dir;
    readViolationConfigFile();

    my @rules;
    foreach my $rule ( split( /\s*,\s*/, $Violation_Config{'defaults'}{'snort_rules'} ) ) {

        #append install_dir if the path doesn't start with /
        $rule = " - $rule" if ( $rule !~ /^\// );
        push @rules, " - $rule";
    }
    $tags{'suricata_rules'} = join( "\n", @rules );
    $logger->info("generating $conf_dir/suricata.yaml");
    parse_template( \%tags, "$conf_dir/suricata.yaml", "$generated_conf_dir/suricata.yaml" );
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
