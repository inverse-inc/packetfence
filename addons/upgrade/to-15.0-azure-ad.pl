#!/usr/bin/perl

=head1 NAME

Azure AD Configuration Migration Script - Migrates and updates Azure AD authentication configuration entries

=head1 DESCRIPTION

This script migrates Azure AD configurations in the authentication INI file. It updates sections where the 'type' is set to 'AzureAD' by modifying the 'user_groups_url' field and adding a new 'graph_url' field if necessary. The script ensures compatibility with updated Azure AD endpoints.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::constants::config;
use pf::constants qw ($TRUE $FALSE);
use pf::file_paths qw(
    $authentication_config_file
);



my $ini = pf::IniFiles->new( -file => $authentication_config_file, -allowempty => 1);
my $changed = 0;

for my $section ($ini->Sections) {
    my $type = $ini->val($section, 'type');
    next if !defined $type || $type ne 'AzureAD';

    my $user_groups_url = $ini->val($section, 'user_groups_url');
    my $token_url       = $ini->val($section, 'token_url');

    next if !defined $user_groups_url && !defined $token_url;

    print "Updating section $section\n";

    if (defined $user_groups_url
        && $user_groups_url ne 'https://graph.microsoft.com/v1.0/users/%USERNAME/memberOf') {
        (my $graph_url = $user_groups_url) =~ s#/v1\.0/users/%USERNAME/memberOf/?$##;
        $ini->newval($section, 'graph_url', $graph_url) if length $graph_url;
    }

    if (defined $token_url
        && $token_url ne 'https://login.microsoftonline.com/%TENANT_ID/oauth2/v2.0/token') {
        (my $oauth_url = $token_url) =~ s#/%TENANT_ID/oauth2/v2\.0/token/?$##;
        $ini->newval($section, 'oauth_url', $oauth_url) if length $oauth_url;
    }

    $ini->delval($section, 'user_groups_url') if defined $user_groups_url;
    $ini->delval($section, 'token_url')       if defined $token_url;
    $changed |= 1;
}

if ($changed) {
    $ini->RewriteConfig();
} else {
    print "Nothing to do\n";
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
