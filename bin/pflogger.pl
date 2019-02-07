#!/usr/bin/perl

=head1 NAME

pflogger - 

=cut

=head1 DESCRIPTION

pflogger

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use POSIX;

my @args;

my $name = $0;

if ($name =~ m#/usr/local/pf/bin/pflogger-(.*)#) {
    push @args, '-t', $1;
}

close_inherited_file_descriptors();
exec('/usr/bin/systemd-cat', @args);

sub close_inherited_file_descriptors {
    my $max = POSIX::sysconf( &POSIX::_POSIX_OPEN_MAX );
    # Close all open file descriptors other than STDIN, STDOUT, and STDERR
    # To avoid resource leaking
    POSIX::close( $_ ) for 3 .. ($max - 1);
}

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

