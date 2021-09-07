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
use Test::More tests => 3;

#This test will running last
use Test::NoWarnings;
{
    my ($cs, $removed) = removeSources("$install_dir/t/data/update-11.1/authentication.conf");
    ok ($cs, "cs remove");
    is_deeply($removed,[qw(Twitter Pinterest AuthorizeNet Instagram Mirapay)]);
    is_deeply([$cs->Sections()] ,[qw(local file1), 'file1 rule admins']);
}

{
    my ($cs, $removed) = removeSources("$install_dir/t/data/update-11.1/authentication_nothing_to_be_done.conf");
    is($cs, undef);
    is($removed, undef);
}

is_deeply(updateProfile(), undef);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

