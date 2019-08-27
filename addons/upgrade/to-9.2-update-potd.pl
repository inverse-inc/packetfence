#!/usr/bin/perl

=head1 NAME

Move password_rotation value from Potd source to guests_admin_registration.access_duration_choices 

=cut

=head1 DESCRIPTION

Moved password_rotation value to guests_admin_registration.access_duration_choices

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use List::MoreUtils qw(uniq);
use pf::IniFiles;
use pf::file_paths qw($authentication_config_file $pf_config_file $pf_default_file);
use pf::authentication;

exit 0 unless -e $authentication_config_file;
exit 0 unless -e $pf_config_file;
exit 0 unless -e $pf_default_file;

my $iniauth =
  pf::IniFiles->new( -file => $authentication_config_file, -allowempty => 1 );

my $config = 
  pf::IniFiles->new(-file => $pf_config_file, -allowempty => 1 );

my $default_pf_config = 
  pf::IniFiles->new(-file => $pf_default_file, -allowempty => 1);

my $access_duration_choices;
my @access_duration;

if ($config->exists('guests_admin_registration', 'access_duration_choices')) {
    $access_duration_choices = $config->val('guests_admin_registration', 'access_duration_choices');
} else {
    $access_duration_choices = $default_pf_config->val('guests_admin_registration', 'access_duration_choices');
}

for my $authsection ( $iniauth->Sections() ) {
    next if $authsection =~ / /;
    if ( defined($iniauth->val($authsection, 'type')) && $iniauth->val($authsection, 'type') eq 'Potd') {
        if (defined($iniauth->val( $authsection, 'password_rotation'))) {
            push @access_duration, $iniauth->val( $authsection, 'password_rotation');
        }
    }
}

if (scalar(@access_duration) > 0 ) {
    $access_duration_choices .= ",". join(',', uniq(@access_duration));
    $access_duration_choices = join(',', uniq(split(',',$access_duration_choices)));
    $config->newval('guests_admin_registration', 'access_duration_choices', $access_duration_choices);
    $config->RewriteConfig();
}

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
