#!/usr/bin/perl -w

=head1 NAME

smoke.t

=head1 DESCRIPTION

A suite of tests quick to run, with no side-effects and that should always pass.

To be used by nightly build systems.

=cut

use strict;
use warnings;
use diagnostics;

use Test::Harness;

use lib qw(t);

# TODO : This should be reworked to be more dynamic
runtests(
    "t/Source/LocalDB.t",
    "t/Model/Endpoint.t",
    "t/Model/Combination.t",
);

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

