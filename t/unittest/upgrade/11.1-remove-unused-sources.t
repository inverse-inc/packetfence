#!/usr/bin/perl

=head1 NAME

o-11.1-remove-unused-sources

=head1 DESCRIPTION

unit test for o-11.1-remove-unused-sources

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}
use pf::file_paths qw($install_dir);
require "$install_dir/addons/upgrade/to-11.1-remove-unused-sources.pl";
use Test::More tests => 13;

#This test will running last
use Test::NoWarnings;
{
    my ($cs, $removed) = removeSources("$install_dir/t/data/update-11.1/authentication.conf");
    ok ($cs, "cs remove");
    is_deeply($removed,[qw(Twitter Pinterest AuthorizeNet Instagram Mirapay)], "remove the correct sources");
    is_deeply([$cs->Sections()] ,[qw(local file1), 'file1 rule admins'], "proper sections are kept");
}

{
    my ($cs, $removed) = removeSources("$install_dir/t/data/update-11.1/authentication_nothing_to_be_done.conf");
    is($cs, undef, "Nothing to do");
    is($removed, undef, "Nothing to remove");
}

{
    my ( $cs, $removed ) = removePortalModules(
        "$install_dir/t/data/update-11.1/portal_modules.conf");
    ok( $cs, "portal modules updated" );
    is_deeply( $removed, [qw(Twitter Pinterest Instagram)], "Removed correct modules" );
    is_deeply(
        [ $cs->Sections() ],
        [
            qw(
              default_policy
              default_pending_policy
              default_registration_policy
              default_login_policy
              default_guest_policy
              default_oauth_policy
              default_billing_policy
              default_saml_policy
              default_blackhole_policy
              default_provisioning_policy
              default_show_local_account
              chain
              oauth_policy
              )
        ],
        "proper sections are kept"
    );

    is(
        $cs->val('oauth_policy', 'multi_source_object_classes'),
        "pf::Authentication::Source::GithubSource,pf::Authentication::Source::GoogleSource",
        "Remove the proper object_classes"
    );

    is(
        $cs->val('chain', 'modules'),
        "default_guest_policy",
        "Remove the proper modules"
    );
}

{
    my $cs = updateProfile(
        "$install_dir/t/data/update-11.1/profiles.conf",
        [qw(Twitter Pinterest Instagram)]
    );

    ok($cs, "Profiles updated");
    is($cs->val('p1', 'sources'), 'Bob', "Remove the proper sources");
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

1;

