#!/usr/bin/perl

=head1 NAME

security_event_config

=head1 DESCRIPTION

unit test for pf::security_event_config

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 5;

#This test will running last
use Test::NoWarnings;
use pf::security_event_config;
use pf::dal::class;

sub class_count {
    my (undef, $count) = pf::dal::class->count();
    return $count;
}

pf::security_event_config::loadSecurityEventsIntoDb();
my $count = class_count();
ok($count > 0, "The security events are loaded");

pf::security_event_config::_loadSecurityEventsIntoDb({});
is(class_count(), $count, "An empty config does not delete the security events");

pf::security_event_config::remove_deleted_security_events([]);
is(class_count(), $count, "Removing with no ids to keep does not delete everything");

pf::security_event_config::remove_deleted_security_events([grep { $_ ne '1100006' } map { $_ eq 'defaults' ? 0 : $_ } keys %pf::security_event_config::SecurityEvent_Config]);
is(class_count(), $count - 1, "A security event no longer in the config is removed");

pf::security_event_config::loadSecurityEventsIntoDb();

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
