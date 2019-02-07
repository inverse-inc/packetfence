#!/usr/bin/perl

=head1 NAME

Syslog

=cut

=head1 DESCRIPTION

unit test for Syslog

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';
use pf::ConfigStore::Syslog;
use pf::constants::syslog;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 3;

#This test will running last
use Test::NoWarnings;

{
    my $config = pf::ConfigStore::Syslog->new;
    my $data = { logs => 'ALL', type => 'server' };
    $config->cleanupAfterRead( "id", $data );
    is_deeply(
        $data,
        {
            logs     => [ split( ',', $pf::constants::syslog::ALL_LOGS ) ],
            all_logs => 'enabled',
            type     => 'server'
        },
        "Expand the virtual field all_logs"
    );
}

{
    my $config = pf::ConfigStore::Syslog->new;
    my $data = { logs => [], all_logs => 'enabled', type => 'server' };
    $config->cleanupBeforeCommit( "id", $data );
    is_deeply(
        $data,
        {
            type => 'server',
            logs => 'ALL',
        },
        "Remove the virtual field all_logs"
    );
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

1;

