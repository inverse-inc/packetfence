package pf::cmd::pf::config;
=head1 NAME

pf::cmd::pf::config add documentation

=head1 SYNOPSIS


pfcmd config <get|set|help> option[=value]

get, set, or display help on pf.conf configuration values

examples:
  pfcmd config get general.hostname
  pfcmd config set general.hostname=new_hostname
  pfcmd config help general.hostname

=head1 DESCRIPTION

pf::cmd::pf::config

=cut

use strict;
use warnings;
use pf::cmd::pf::config::help;
use base qw(pf::cmd::subcmd);

sub helpActionCmd { "pf::cmd::pf::config::help" }

sub noActionCmd {
    return $_[0]->SUPER::helpActionCmd;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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

