package pf::pftest;

=head1 NAME

pf::pftest add documentation

=head1 SYNOPSIS

pftest <cmd> [options]

 Commands
  authentication              | checks authentication sources
  mysql                       | runs the mysql tuner
  profile_filter              | checks which profile will be used for a mac
  locationlog                 | checks for multiple open locationlog entries

Please view "pftest.pl help <command>" for details on each option

=head1 DESCRIPTION

pf::pftest

=cut

use strict;
use warnings;
use base qw(pf::cmd::subcmd);
use pf::pftest::help; #Preload help

sub helpActionCmd { "pf::pftest::help" }

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

