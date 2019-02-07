#!/usr/bin/perl
=head1 NAME

backend_modperl_require.pl

=head1 DESCRIPTION

Pre-loading PacketFence's modules in Apache (mod_perl) for the Web Admin / Web Services Back-End

=cut

use lib "/usr/local/pf/lib";
# dynamicly loaded authentication modules
use lib "/usr/local/pf/conf";

use strict;
use warnings;


use pf::config;
use pf::locationlog;
use pf::node;
use pf::roles::custom;
use pf::Switch;
use pf::SwitchFactory;
use pf::util;

# Forces a pre-load of the singletons to avoid penalty performance on first request
pf::roles::custom->instance();

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

1;
