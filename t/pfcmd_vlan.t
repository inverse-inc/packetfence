#!/usr/bin/perl -w

=head1 NAME

pfcmd_vlan.t

=head1 DESCRIPTION

Testing pfcmd_vlan command line interface (CLI)

=cut

use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 2;
use Test::NoWarnings;

use English '-no_match_vars';
use File::Basename qw(basename);
use Log::Log4perl;

# required to avoid warnings in admin guide asciidoc build
`perl -I/usr/local/pf/t -Mtest_paths /usr/local/pf/bin/pfcmd_vlan -help`;
is($CHILD_ERROR, 0, "pfcmd_vlan -help exits with status 0"); 

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

