#!/usr/bin/perl

=head1 NAME

fingerbank_invalid_mac

=head1 DESCRIPTION

pf::fingerbank::process doesn't look up or retry an invalid MAC address

=cut

use strict;
use warnings;
# pf core libs
BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 8;
use Test::MockModule;

#This test will run last
use Test::NoWarnings;
use pf::fingerbank;

my @queued;
my $queue = Test::MockModule->new('pf::api::queue');
$queue->mock('notify_delayed', sub { my ($self, @args) = @_; push @queued, \@args; return });

my $fb_config = Test::MockModule->new('fingerbank::Config');
$fb_config->mock('is_api_key_configured', sub { 1 });

my $lookups = 0;
my $fingerbank = Test::MockModule->new('pf::fingerbank');
$fingerbank->mock('endpoint_attributes', sub { $lookups++; return undef });
$fingerbank->mock('_query', sub { $lookups++; return undef });

# pf::ip4log::ip2mac returns 0 for an IP address without a known MAC address
for my $mac (0, '0', undef, '', 'not-a-mac') {
    ok(!pf::fingerbank::process($mac), "process of '" . ($mac // 'undef') . "' returns false");
}

is($lookups, 0, 'no lookup for an invalid MAC address');
is(scalar @queued, 0, 'and no retry');

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
