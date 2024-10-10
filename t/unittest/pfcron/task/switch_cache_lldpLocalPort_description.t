#!/usr/bin/perl

=head1 NAME

switch_cache_lldpLocalPort_description

=head1 DESCRIPTION

unit test for switch_cache_lldpLocalPort_description

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 3;

#This test will running last
use Test::NoWarnings;
use pf::pfcron::task::switch_cache_lldpLocalPort_description;
use pf::Switch;

{
    my $task = pf::pfcron::task::switch_cache_lldpLocalPort_description->new(
        {
            status   => "enabled",
            id       => 'test',
            interval => 0,
            type     => 'switch_cache_lldpLocalPort_description',
        }
    );

    my $hash = {};

    {
        no warnings qw(redefine);
        local *pf::Switch::getLldpLocPortDesc =
          sub {  $hash->{$_[0]->{_id}} = 1  };
        $task->run();
    }

    is_deeply( $hash, { '172.16.8.31' => 1 } );
}

{
    my $task = pf::pfcron::task::switch_cache_lldpLocalPort_description->new(
        {
            status   => "enabled",
            id       => 'test',
            interval => 0,
            type     => 'switch_cache_lldpLocalPort_description',
            process_switchranges => 'enabled',
        }
    );

    my $hash = {};

    {
        no warnings qw(redefine);
        local *pf::Switch::getLldpLocPortDesc =
          sub {  $hash->{$_[0]->{_id}} = 1  };
        $task->run();
    }

    is_deeply( $hash, { '172.16.8.31' => 1, (map { ("172.16.9.$_" => 1) } (1...254) ) } );
}

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

