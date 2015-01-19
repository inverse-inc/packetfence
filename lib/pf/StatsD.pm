package pf::StatsD;

=head1 NAME

pf::StatsD - PacketFence StatsD support

=cut

=head1 DESCRIPTION

pf::StatsD  contains the code necessary to create a Global StatsD object.


=head1 CONFIGURATION AND ENVIRONMENT

Read the following configuration files: F<pf.conf.defaults>

=cut

use strict;
use warnings;
use Etsy::StatsD;
use pf::config;

our $VERSION = 1.000000;

our @EXPORT = qw($statsd);

our $statsd;

initStatsd();

sub initStatsd {
    $statsd = Etsy::StatsD->new($Config{'monitoring'}{'statsd_host'}, $Config{'monitoring'}{'statsd_port'},);
}


sub CLONE {
    initStatsd;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2014 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
