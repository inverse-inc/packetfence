#!/usr/bin/perl

=head1 NAME

unregister_on_unmatch

=head1 DESCRIPTION

unit test for pf::radius::_unregister_on_unmatch

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 8;

#This test will running last
use Test::NoWarnings;
use pf::radius;

{
    package test::profile;
    sub new { my ($class, $unset) = @_; bless { unset => $unset }, $class }
    sub dot1xUnsetOnUnmatch { $_[0]{unset} }
    sub getName { 'test' }
}

my $radius = pf::radius->new;
my $unset = test::profile->new('enabled');
my $keep = test::profile->new('disabled');

ok($radius->_unregister_on_unmatch({ mac => '00:11:22:33:44:55', profile => $unset }, { status => 'unreg' }), 'no rule matched and unset on unmatch: stays unregistered');
ok(!$radius->_unregister_on_unmatch({ mac => '00:11:22:33:44:55', profile => $keep }, { status => 'unreg' }), 'unset on unmatch disabled: registered as before');
ok(!$radius->_unregister_on_unmatch({ mac => '00:11:22:33:44:55', profile => $unset }, { status => 'reg', category => 'guest' }), 'a rule matched: registered');
ok(!$radius->_unregister_on_unmatch({ mac => '00:11:22:33:44:55', profile => $unset }, {}), 'no status computed: registered');
ok(!$radius->_unregister_on_unmatch({ mac => '00:11:22:33:44:55' }, { status => 'unreg' }), 'no profile: registered');
ok(!$radius->_unregister_on_unmatch({ mac => '00:11:22:33:44:55', profile => $unset }, { status => 'unreg', category => 'gaming' }), 'no rule matched but a provisioner applied a role: registered with it');

my $node = { status => 'reg', autoreg => 'yes', regdate => '2026-10-01 10:00:00', unregdate => '2026-11-01 10:00:00' };
pf::radius::_keep_unregistered($node);
is_deeply($node, { status => 'unreg', autoreg => 'no', regdate => '0000-00-00 00:00:00', unregdate => '0000-00-00 00:00:00' }, 'a node kept unregistered loses its autoregistration and registration dates, as with node_deregister');

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
