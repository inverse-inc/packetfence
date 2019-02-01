#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-8.3-authentication-searchattributes.pl

=cut

=head1 DESCRIPTION

Define searchattributes value in AD and LDAP source if it doesn't exist

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::IniFiles;
use pf::file_paths qw($authentication_config_file);
use pf::util;
run_as_pf();

exit 0 unless -e $authentication_config_file;

my $iniauth =
  pf::IniFiles->new( -file => $authentication_config_file, -allowempty => 1 );

for my $authsection ( $iniauth->Sections() ) {
    next if $authsection =~ / /;
    if ( defined($iniauth->val($authsection, 'type')) && ($iniauth->val($authsection, 'type') eq 'AD' || $iniauth->val($authsection, 'type') eq 'LDAP' )) {

        my $searchattributes_exists = $iniauth->exists($authsection, 'searchattributes');

        if (!$searchattributes_exists) {
            $iniauth->newval($authsection, 'searchattributes', '');
        }
    }
}

$iniauth->RewriteConfig();

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

