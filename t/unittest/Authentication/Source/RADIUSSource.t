#!/usr/bin/perl

=head1 NAME

RADIUSSource

=head1 DESCRIPTION

unit test for the RADIUS client of RADIUSSource (#8213)

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

use Test::More tests => 3;
use pf::Authentication::Source::RADIUSSource;
use Authen::Radius;

#This test will running last
use Test::NoWarnings;

my %client_args;
{
    no warnings 'redefine';
    # Capture the arguments of the RADIUS client and fail the connection
    *Authen::Radius::new = sub { my ($class, %args) = @_; %client_args = %args; return undef };
}

my $source = pf::Authentication::Source::RADIUSSource->new({
    id => 'radius_test',
    host => '192.0.2.10',
    port => 1812,
    secret => 'secret',
    timeout => 1,
    use_connector => 0,
    monitor => 0,
    options => 'type = auth',
});

my ($result) = $source->authenticate('bob', 'password');
is($client_args{Host}, '192.0.2.10:1812', "RADIUS client for the server of the source");
ok($client_args{Rfc3579MessageAuth}, "the Access-Request carries a Message-Authenticator");

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
