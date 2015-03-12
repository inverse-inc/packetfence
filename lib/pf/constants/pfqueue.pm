package pf::constants::pfqueue;

=head1 NAME

pf::constants::pfqueue add documentation

=cut

=head1 DESCRIPTION

pf::constants::pfqueue

=cut

use strict;
use warnings;
use base qw(Exporter);

our @EXPORT_OK = qw(
  $QUEUE_DELAYED_HASH
  $QUEUE_DELAYED_QUEUE
  $QUEUE_DELAYED_ZSET
  $QUEUE_DYNAMIC_PREFIX
  $QUEUE_PREFIX
);

our $QUEUE_DELAYED_ZSET   = "delayed-zset";
our $QUEUE_DELAYED_QUEUE  = "queue-delayed";
our $QUEUE_DELAYED_HASH   = "queue-delayed-data";
our $QUEUE_PREFIX         = "queue";
our $QUEUE_DYNAMIC_PREFIX = "queue-dynamic";

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

