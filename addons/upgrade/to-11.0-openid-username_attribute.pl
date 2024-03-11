#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-11.0-openid-username_attribute.pl

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

exit 0 unless -e $authentication_config_file;

run_as_pf();

my $config = pf::IniFiles->new(-file => $pf_config_file, -allowempty => 1 );
my $default_pf_config = pf::IniFiles->new(-file => $pf_default_file, -allowempty => 1);
my $default_openid_attributes = $default_pf_config->val('advanced', 'openid_attributes');
my %defaultUsernameAttribute = map { $_ => undef  } split(/\s*,\s*/, $default_openid_attributes // '');
my $openid_attributes = $config->val('advanced', 'openid_attributes');
my $iniauth = pf::IniFiles->new( -file => $authentication_config_file, -allowempty => 1 );
my @attributes = split(/\s*,\s*/, $openid_attributes // '');

for my $authsection ( grep { /^\S+$/ } $iniauth->Sections() ) {
    next if $iniauth->val($authsection, 'type') ne 'OpenID';
    my $val = $iniauth->val($authsection, 'username_attribute');
    if (defined $val && length ($val) > 0) {
        push @attributes, $val;
    }
}

@attributes = uniq grep { !exists $defaultUsernameAttribute{$_} } @attributes;
if (@attributes) {
    my $val = join(",", @attributes);
    if ($openid_attributes) {
        $config->setval('advanced', 'openid_attributes', $val);
    } else {
        $config->newval('advanced', 'openid_attributes', $val);
    }

    $config->RewriteConfig();
    print "Updated advanced.openid_attributes to '$val'\n";
    exit;
}

print "Nothing to update\n";

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

