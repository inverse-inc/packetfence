#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-10.1-authentication-prefix.pl

=cut

=head1 DESCRIPTION

Rewrite radius attributes in the rules condition

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($authentication_config_file $pf_config_file $pf_default_file);
use pf::util;
use List::MoreUtils qw(uniq);

run_as_pf();

exit 0 unless -e $authentication_config_file;

my @radius_attributes = qw(
        TLS-Client-Cert-Serial
        TLS-Client-Cert-Expiration
        TLS-Client-Cert-Issuer
        TLS-Client-Cert-Subject
        TLS-Client-Cert-Common-Name
        TLS-Client-Cert-Filename
        TLS-Client-Cert-Subject-Alt-Name-Email
        TLS-Client-Cert-X509v3-Extended-Key-Usage
        TLS-Cert-Serial
        TLS-Cert-Expiration
        TLS-Cert-Issuer
        TLS-Cert-Subject
        TLS-Cert-Common-Name
        TLS-Client-Cert-Subject-Alt-Name-Dns
    );


my $config =
  pf::IniFiles->new(-file => $pf_config_file, -allowempty => 1 );

my $default_pf_config =
  pf::IniFiles->new(-file => $pf_default_file, -allowempty => 1);

my @radius_attributes_from_config;

if ($config->exists('radius_configuration', 'radius_attributes')) {
    @radius_attributes_from_config = split(',', $config->val('radius_configuration', 'radius_attributes'));
} else {
    @radius_attributes_from_config = split(',', $default_pf_config->val('radius_configuration', 'radius_attributes'));
}

push (@radius_attributes, @radius_attributes_from_config);

my $iniauth =
  pf::IniFiles->new( -file => $authentication_config_file, -allowempty => 1 );

for my $authsection ( $iniauth->Sections() ) {
    next if $authsection !~ /\w+\s+rule\s+\w+/;
    foreach my $key ($iniauth->Parameters($authsection)) {
        next if $key !~ /condition.*/;
        if (grep({ $iniauth->val($authsection, $key) =~ /^$_/ } uniq(@radius_attributes)) ) {
            my $val = $iniauth->val($authsection, $key);
            print "replace $val to radius_request.$val in $authsection\n";
            $iniauth->newval($authsection, $key, "radius_request.".$iniauth->val($authsection, $key));
        }
    }
}

$iniauth->RewriteConfig();

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

