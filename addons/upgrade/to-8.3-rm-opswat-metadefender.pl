#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-8.3-rm-opswat-metadefender.pl

=cut

=head1 DESCRIPTION

Remove old config items for metadefender

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::IniFiles;
use pf::file_paths qw($pf_config_file $violations_config_file);
use pf::util;
run_as_pf();
my $ini = pf::IniFiles->new(-file => $pf_config_file, -allowempty => 1);
if ($ini && $ini->SectionExists('metadefender')) {
    $ini->DeleteSection();
    $ini->RewriteConfig();
}

$ini = pf::IniFiles->new(-file => $violations_config_file, -allowempty => 1);
if ($ini) {
    for my $section ($ini->Sections()) {
        my $trigger = $ini->val($section, "trigger");
        next unless defined $trigger;
        print "Upgrading $section\n";
        $trigger = join("," , grep { !/^metadefender/} split (/\s*,\s*/, $trigger));
        $ini->setval($section, "trigger", $trigger);
    }
}
$ini->RewriteConfig();


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

