#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-10.1-move-radius-configuration-parameter.pl

=cut

=head1 DESCRIPTION

Move radius configuration parameters to associated new files

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($pf_config_file $ocsp_config_file $eap_config_file $fast_config_file);
use pf::util;
run_as_pf();

my $ini = pf::IniFiles->new(-file => $pf_config_file, -allowempty => 1);
my $eap = pf::IniFiles->new(-file => $eap_config_file, -allowempty => 1);
my $ocsp = pf::IniFiles->new(-file => $ocsp_config_file, -allowempty => 1);
my $fast = pf::IniFiles->new(-file => $fast_config_file, -allowempty => 1);

unless ($ini) {
    exit;
}

if (!$ini->exists('radius_configuration', 'eap_authentication_types') && !$ini->exists('radius_configuration', 'eap_fast_opaque_key') &&
    !$ini->exists('radius_configuration', 'eap_fast_authority_identity') && !$ini->exists('radius_configuration', 'ocsp_enable') &&
    !$ini->exists('radius_configuration', 'ocsp_override_cert_url') && !$ini->exists('radius_configuration', 'ocsp_url') &&
    !$ini->exists('radius_configuration', 'ocsp_use_nonce') && !$ini->exists('radius_configuration', 'ocsp_timeout') &&
    !$ini->exists('radius_configuration', 'ocsp_softfail') ) {
    print ("Nothing to do\n");
    exit;
}

if ($ini->exists('radius_configuration', 'eap_authentication_types')) {
    my $val = $ini->val('radius_configuration', 'eap_authentication_types');
    $ini->delval('radius_configuration', 'eap_authentication_types');
    $eap->newval('default', 'eap_authentication_types', $val);
}

if ($ini->exists('radius_configuration', 'eap_fast_opaque_key')) {
    my $val = $ini->val('radius_configuration', 'eap_fast_opaque_key');
    $ini->delval('radius_configuration', 'eap_fast_opaque_key');
    $fast->newval('default', 'pac_opaque_key', $val);
}

if ($ini->exists('radius_configuration', 'eap_fast_authority_identity')) {
    my $val = $ini->val('radius_configuration', 'eap_fast_authority_identity');
    $ini->delval('radius_configuration', 'eap_fast_authority_identity');
    $fast->newval('default', 'authority_identity', $val);
}

if ($ini->exists('radius_configuration', 'ocsp_enable')) {
    my $val = $ini->val('radius_configuration', 'ocsp_enable');
    $ini->delval('radius_configuration', 'ocsp_enable');
    $ocsp->newval('default', 'ocsp_enable', $val);
}

if ($ini->exists('radius_configuration', 'ocsp_override_cert_url')) {
    my $val = $ini->val('radius_configuration', 'ocsp_override_cert_url');
    $ini->delval('radius_configuration', 'ocsp_override_cert_url');
    $ocsp->newval('default', 'ocsp_override_cert_url', $val);
}

if ($ini->exists('radius_configuration', 'ocsp_url')) {
    my $val = $ini->val('radius_configuration', 'ocsp_url');
    $ini->delval('radius_configuration', 'ocsp_url');
    $ocsp->newval('default', 'ocsp_url', $val);
}

if ($ini->exists('radius_configuration', 'ocsp_use_nonce')) {
    my $val = $ini->val('radius_configuration', 'ocsp_use_nonce');
    $ini->delval('radius_configuration', 'ocsp_use_nonce');
    $ocsp->newval('default', 'ocsp_use_nonce', $val);
}

if ($ini->exists('radius_configuration', 'ocsp_timeout')) {
    my $val = $ini->val('radius_configuration', 'ocsp_timeout');
    $ini->delval('radius_configuration', 'ocsp_timeout');
    $ocsp->newval('default', 'ocsp_timeout', $val);
}

if ($ini->exists('radius_configuration', 'ocsp_softfail')) {
    my $val = $ini->val('radius_configuration', 'ocsp_softfail');
    $ini->delval('radius_configuration', 'ocsp_softfail');
    $ocsp->newval('default', 'ocsp_softfail', $val);
}

$eap->RewriteConfig();
$fast->RewriteConfig();
$ocsp->RewriteConfig();

$ini->RewriteConfig();

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

