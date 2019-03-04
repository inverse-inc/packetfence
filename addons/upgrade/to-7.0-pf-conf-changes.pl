#!/usr/bin/perl

=head1 NAME

to-7.0-pf-conf-changes.pl

=cut

=head1 DESCRIPTION

Multiple sections/parameters have been renamed or deprecated in pf.conf
Rename the appropriate sections/parameters and warn on the deprecated ones

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';

use pf::file_paths qw($pf_config_file);
use pf::IniFiles;
use pf::util;

run_as_pf();

my $config = pf::IniFiles->new(-file => $pf_config_file) or die $!;

my %SECTIONS_TO_RENAME = (
    trapping => "fencing",
    vlan => "snmp_traps",
    registration => "device_registration",
    monitoring => "graphite",
);

print "\n!!!! RENAMED SECTIONS: !!!!!\n";
while(my ($orig, $new) = each(%SECTIONS_TO_RENAME)) {
    print "Renaming section $orig to $new \n";
    $config->RenameSection($orig, $new);
}

my %PARAMS_TO_RENAME = (
    'advanced.pfdhcplistener_packet_size' => 'services.pfdhcplistener_packet_size',
    # registration.device_registration and registration.device_registration_role are now in device_registration with the section rename above
    'device_registration.device_registration' => 'device_registration.status',
    'device_registration.device_registration_role' => 'device_registration.role',
);

print "\n!!!! RENAMED PARAMETERS: !!!!!\n";
while(my ($orig, $new) = each(%PARAMS_TO_RENAME)) {
    my ($orig_section, $orig_param) = split(/\./, $orig);
    my ($new_section, $new_param) = split(/\./, $new);

    print "Moving parameter $orig_param from section $orig_section to $new_section.$new_param \n";


    if($config->exists($orig_section, $orig_param)) {
        my $orig_val = $config->val($orig_section, $orig_param);
        # Delete any existing destination (new) parameter
        $config->delval($new_section, $new_param);

        # Set the value of the new parameter with the value of the old one
        $config->AddSection($new_section);
        $config->newval($new_section, $new_param, $orig_val);

        # Delete the old deprecated value
        $config->delval($orig_section, $orig_param);
    }
}

my %DEPRECATED_PARAMS = (
    'services.suricata' => 1,
    'services.suricata_binary' => 1,
    'services.snort' => 1,
    'services.snort_binary' => 1,
    'general.dnsservers' => 1,
    'trapping.detection_engine' => 1,
    'alerting.log' => 1,
    'trapping.wireless_ips' => 1,
    'trapping.wireless_ips_threshold' => 1,
    'servicewatch.email' => 1,
    'servicewatch.restart' => 1,
    'advanced.reevaluate_access_reasons' => 1,
    'advanced.pfcmd_error_color' => 1,
    'advanced.pfcmd_warning_color' => 1,
    'advanced.pfcmd_success_color' => 1,
);

print "\n!!!! DEPRECATED PARAMETERS: !!!!!\n";
my $has_deprecated = 0;
while(my ($param) = each(%DEPRECATED_PARAMS)) {
    my ($section, $name) = split(/\./, $param);
    if($config->val($section, $name)) {
        print "The parameter $param is officially deprecated and has no effect anymore. You should remove it from the configuration to avoid any warnings.\n";
        $has_deprecated = 1;
    }
}

print "No deprecated parameter detected\n" unless($has_deprecated);

$config->RewriteConfig();

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

