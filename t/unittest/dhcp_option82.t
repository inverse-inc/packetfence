#!/usr/bin/perl

=head1 NAME

dhcp_option82

=head1 DESCRIPTION

unit test for dhcp_option82

=cut

use strict;
use warnings;
#
BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 4;

#This test will running last
use Test::NoWarnings;
use pf::dhcp_option82 qw(dhcp_option82_insert_or_update dhcp_option82_view);


my $mac = 'ff:99:77:55:33:11';

dhcp_option82_insert_or_update(
    mac => $mac
);

my $item = dhcp_option82_view($mac);
my $created_at = $item->{created_at};
#This is the first test
ok ($created_at ne '0000-00-00 00:00:00', "Created is not null");

sleep(1);
dhcp_option82_insert_or_update(
    mac => $mac,
    port => 'sds',
);

$item = dhcp_option82_view($mac);
is($created_at,  $item->{created_at}, "Created at Stayed the same");
is('sds',  $item->{port}, "Port was updated");

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

