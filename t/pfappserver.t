#!/usr/bin/perl
=head1 NAME

casperjs

=cut

=head1 DESCRIPTION

unit test for casperjs

=cut

use strict;
use warnings;
#
use lib qw(
  /usr/local/pf/lib
  /usr/local/pf/html/captiveportal/lib
  /usr/local/pf/html/pfappserver/lib
);

our $casper_tests;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
    $casper_tests = 3;
}

use catalyst_runner;

use Test::More tests => $casper_tests + 1;

#This test will running last
use Test::NoWarnings;

SKIP: {
    my $runner = catalyst_runner->new(app => 'pfappserver');
    my ($port, $status) = $runner->start_catalyst_server;
    skip "The Catalyst Service could not be started", $casper_tests if $status ne 'ready';
    my $base_url = "http://localhost:$port/";
    casperjs_ok("login_admin.js", "--base_url=$base_url --username=admin --password=admin2 --is_password_valid=false");
    casperjs_ok("login_admin.js", "--base_url=$base_url --username=admin --password=admin --is_password_valid=true");
    casperjs_ok("logout_admin.js", "--base_url=$base_url --username=admin --password=admin");
}

sub casperjs_ok {
    my ($script, $options, $msg) = @_;
    my $cmd = "casperjs test /usr/local/pf/t/casperjs/$script $options";
    $msg //= $cmd;
    local $?;
    system($cmd);
    ok($? == 0, $msg);
}


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

