#!/usr/bin/perl

=head1 NAME

Source

=head1 DESCRIPTION

unit test for Source

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}
#
{
    package pf::Authentication::Source::RoleLookupSource;
    use Moose;
    extends 'pf::Authentication::Source';
    has roleLookup => ( is => 'rw');
    sub lookupRole {
        my ($self, $lookupId) = @_;
        return $self->roleLookup->{$lookupId}
    }
}

{
    package pf::Authentication::Source::DummySource;
    use Moose;
    extends 'pf::Authentication::Source';
}

use Test::More tests => 5;

#This test will running last
use Test::NoWarnings;
use pf::authentication;
$pf::authentication::TYPE_TO_SOURCE{rolelookup} = 'pf::Authentication::Source::RoleLookupSource';
$pf::authentication::TYPE_TO_SOURCE{dummy} = 'pf::Authentication::Source::DummySource';

my $source =
  newAuthenticationSource( "RoleLookup", "RoleLookup", { roleLookup => { name => 'nameOfTheRole'} } );

ok($source, "Source created");

is($source->lookupRole('name'), 'nameOfTheRole');

$source =
  newAuthenticationSource( "Dummy", "Dummy", {} );

ok($source, "Source created");

is($source->lookupRole('name'), undef);


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

