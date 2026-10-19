#!/usr/bin/perl

=head1 NAME

constants

=head1 DESCRIPTION

The URLs polled by the portal waiting rooms must reach the captive portal:
pf::web::dispatcher answers 501 to any URL that isn't a portal resource

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 4;
use pf::web::constants;

#This test will running last
use Test::NoWarnings;

like('/sponsor/check', $WEB::CAPTIVE_PORTAL_RESOURCES, "The sponsor waiting room check is a portal resource");
like('/email/check', $WEB::CAPTIVE_PORTAL_RESOURCES, "The email waiting room check is a portal resource");
unlike('/email/check/other', $WEB::CAPTIVE_PORTAL_RESOURCES, "The email check URL is anchored at its end");

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

1;
