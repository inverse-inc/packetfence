#!/usr/bin/perl

=head1 NAME

export

=head1 DESCRIPTION

unit test for export

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 3;
my $EXPORT_SCRIPT = '/usr/local/pf/addons/export';

#This test will running last
use Test::NoWarnings;
use IPC::Open3;
use Symbol 'gensym'; # vivify a separate handle for STDERR

{
    my ($pid, $chld_in, $chld_out, $chld_err) = run_script();
    ok($pid, "$EXPORT_SCRIPT can run");
    waitpid($pid, 0);
    my $child_exit_status = $? >> 8;
    is ($child_exit_status, 0, "status is zero");
}

sub run_script {
    my $pid = open3(my $chld_in, my $chld_out, my $chld_err = gensym, $EXPORT_SCRIPT, @_);
    return $pid, $chld_in, $chld_out, $chld_err;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

