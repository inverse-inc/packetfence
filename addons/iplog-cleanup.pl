#!/usr/bin/perl
=head1 NAME

iplog-cleanup.pl - runs the iplog clean task

=head1 SYNOPSIS

iplog-cleanup.pl [--expire SECONDS] [--batch BATCH] [--timeout SECONDS]

 Options:
  --expire   The expire time of the iplog in seconds     - default expire.iplog
  --batch    The number of iplog entries to batch delete - default maintenance.iplog_cleanup_batch
  --timeout  How long this job is allowed to run         - default maintenance.iplog_cleanup_timeout
  --help     Shows this help

=head1 DESCRIPTION

iplog-cleanup

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::config;
use pf::iplog;

use Getopt::Long;
use Pod::Usage;

my %options = (
    expire   => $Config{'expire'}{'iplog'},
    batch    => $Config{maintenance}{iplog_cleanup_batch},
    timeout  => $Config{maintenance}{iplog_cleanup_timeout},
    help     => undef,
);

GetOptions(\%options,"expire=s","batch=s","timeout=s","help|h") || pod2usage(2);

pod2usage(1) if $options{help};

pod2usage(-msg  => "Expire must be greater than 0", -exitval => 2, -verbose => 0) unless $options{expire};

pf::iplog::cleanup(@options{qw(expire batch timeout)});

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

