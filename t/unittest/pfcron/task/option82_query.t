#!/usr/bin/perl

=head1 NAME

option82_query

=head1 DESCRIPTION

unit test for option82_query

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 2;

#This test will running last
use Test::NoWarnings;
use pf::pfcron::task::option82_query;
use pf::option82;
use pf::Switch::TestOption82;
use pf::Switch::Cisco::Cisco_IOS_12_x;

{
    no warnings qw(redefine);
    #improve speed
    local *pf::Switch::Cisco::Cisco_IOS_12_x::getRelayAgentInfoOptRemoteIdSub = sub { undef };
    my $task = pf::pfcron::task::option82_query->new(
         {
             status   => "enabled",
             id       => 'test',
             interval  => 0,
             type     => 'option82_query',
         }
     );

    $task->run();
}

is(pf::option82::get_switch_from_option82($pf::Switch::TestOption82::OPTION82_MAC), '172.16.8.31');

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

