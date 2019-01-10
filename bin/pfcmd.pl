#!/usr/bin/perl -T
=head1 NAME

pfcmd

=cut

=head1 DESCRIPTION

driver script for pfcmd

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);

# force UID/EUID to root to allow socket binds, etc
# required for non-root (and GUI) service restarts to work
$> = 0;
$< = 0;

# To ensure group permissions are properly added
umask(0007);
$ENV{PATH} = "/sbin:/usr/sbin:/bin:/usr/bin";

use pf::cmd::pf;
exit pf::cmd::pf->new({args => \@ARGV})->run();

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
