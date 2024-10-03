#!/usr/bin/perl

=head1 NAME

freeze

=head1 DESCRIPTION

unit test for object

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 4;
use pf::config::crypt::object;
use pf::config::crypt::object::freeze;
use pf::Sereal qw($DECODER $ENCODER_FREEZER);
use Sereal::Encoder qw(sereal_encode_with_object);
use Sereal::Decoder qw(sereal_decode_with_object);

#This test will running last
use Test::NoWarnings;
our %authentication_lookup;
tie %authentication_lookup, 'pfconfig::cached_hash', 'resource::authentication_lookup';

my $secret = 'secret';
my $object = pf::config::crypt::object->new($secret);
my $frozen =  $object->FREEZE(undef);
my $thawed = $object->THAW(undef, $frozen);
is($secret, $thawed, "Data frozen and thawed");

my $data = sereal_encode_with_object($ENCODER_FREEZER, $object);
$thawed = sereal_decode_with_object($DECODER, $data);
is($secret, $thawed, "Data frozen and thawed");

use Data::Dumper; print Dumper($authentication_lookup{LDAPWITHENCRYPTEDPASSWORD});
is($secret, $authentication_lookup{LDAPWITHENCRYPTEDPASSWORD}{password}, "Data frozen and thawed from pfconfig");

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

