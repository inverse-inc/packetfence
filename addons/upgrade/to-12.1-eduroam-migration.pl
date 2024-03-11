#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-12.1-eduroam-migration.pl

=cut

=head1 DESCRIPTION

Move eduroam configuration

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::util;
use pf::file_paths qw($authentication_config_file);

run_as_pf();

exit 0 unless -e $authentication_config_file;

my $iniauth =
  pf::IniFiles->new( -file => $authentication_config_file, -allowempty => 1 );

my $saved_authsection = 0;
for my $authsection ( $iniauth->Sections() ) {
    if ( defined($iniauth->val($authsection, 'type')) && ($iniauth->val($authsection, 'type') eq 'Eduroam') ) {
        $saved_authsection = $authsection;
    }
}

if ($saved_authsection) {
    # Create the 2 Radius sources
    $iniauth->AddSection("RadiusEduroam1");
    $iniauth->AddSection("RadiusEduroam2");
    $iniauth->newval("RadiusEduroam1", 'type' , 'RADIUS');
    $iniauth->newval("RadiusEduroam1", 'host' , $iniauth->val($saved_authsection, 'server1_address'));
    $iniauth->newval("RadiusEduroam1", 'secret' , $iniauth->val($saved_authsection, 'radius_secret'));
    $iniauth->newval("RadiusEduroam1", 'port' , $iniauth->val($saved_authsection, 'server1_port'));
    $iniauth->newval("RadiusEduroam1", 'options' , 'type = auth');
    $iniauth->newval("RadiusEduroam1", 'description' , 'Eduroam1');
    $iniauth->newval("RadiusEduroam1", 'timeout' , '1');
    $iniauth->newval("RadiusEduroam2", 'type' , 'RADIUS');
    $iniauth->newval("RadiusEduroam2", 'host' , $iniauth->val($saved_authsection, 'server2_address'));
    $iniauth->newval("RadiusEduroam2", 'secret' , $iniauth->val($saved_authsection, 'radius_secret'));
    $iniauth->newval("RadiusEduroam2", 'port' , $iniauth->val($saved_authsection, 'server2_port'));
    $iniauth->newval("RadiusEduroam2", 'options' , 'type = auth');
    $iniauth->newval("RadiusEduroam2", 'description' , 'Eduroam2');
    $iniauth->newval("RadiusEduroam2", 'timeout' , '1');

    # Add proxy config
    $iniauth->newval($saved_authsection, 'eduroam_radius_auth', 'RadiusEduroam1,RadiusEduroam2');
    $iniauth->newval($saved_authsection, 'eduroam_options', 'nostrip');
    $iniauth->newval($saved_authsection, 'eduroam_radius_auth_proxy_type', 'keyed-balance');

    # Removed old values
    $iniauth->delval($saved_authsection, 'server1_address');
    $iniauth->delval($saved_authsection, 'server2_address');
    $iniauth->delval($saved_authsection, 'server1_port');
    $iniauth->delval($saved_authsection, 'server2_port');
    $iniauth->delval($saved_authsection, 'radius_secret');

    $iniauth->RewriteConfig();
}

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

