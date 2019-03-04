#!/usr/bin/perl

=head1 NAME

dal-log

=cut

=head1 DESCRIPTION

unit test for dal-log

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    use Log::Log4perl;
    my $conf = q(
    log4perl.rootLogger =  INFO, TEST
    log4perl.appender.TEST = Log::Log4perl::Appender::TestBuffer
    log4perl.appender.TEST.layout = SimpleLayout
    );
    Log::Log4perl::init( \$conf );
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 4;

#This test will running last
use Test::NoWarnings;
use pf::dal;

#This is the first test

my $bad_sql = "SELECT garbage from node;";
ok my $appender = Log::Log4perl->appenders()->{TEST}, 'able to fetch test appender';
{
    local $pf::dal::ALLOWED_ERROR = 500;
    my ($status, $sth) = pf::dal->db_execute($bad_sql);
    is ($appender->buffer, '', "Should be empty");
}
my $status = pf::dal->db_execute($bad_sql);
ok ($appender->buffer ne '', "Should have content");

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

