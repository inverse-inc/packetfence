#!/usr/bin/perl

=head1 NAME

FloatingDevice

=head1 DESCRIPTION

unit test for FloatingDevice

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
use pf::validator::Config::FloatingDevice;

use Test::Exception;
#This test will running last
use Test::NoWarnings;

lives_ok { my $v = pf::validator::Config::FloatingDevice->new(); } 'Create a FloatingDevice validator';

{
    my $v = pf::validator::Config::FloatingDevice->new();

    is_deeply(
        $v->optionsMeta(),
        do {
            my $a = {
                id => {
                    default => undef,
                    implied => undef,
                    pattern => {
                        message => "Mac Address",
                        regex   =>
                          "[0-9A-Fa-f][0-9A-Fa-f](:[0-9A-Fa-f][0-9A-Fa-f]){5}",
                    },
                    placeholder => undef,
                    required    =>
                      bless( do { \( my $o = 1 ) }, "JSON::PP::Boolean" ),
                    type => "string",
                },
                ip => {
                    default     => undef,
                    implied     => undef,
                    placeholder => undef,
                    required    =>
                      bless( do { \( my $o = 0 ) }, "JSON::PP::Boolean" ),
                    type => "string",
                },
                pvid => {
                    default     => undef,
                    implied     => undef,
                    min_value   => 0,
                    placeholder => undef,
                    required    => 'fix',
                    type        => "integer",
                },
                taggedVlan => {
                    default     => undef,
                    implied     => undef,
                    placeholder => undef,
                    required    => 'fix',
                    type        => "string",
                },
                trunkPort => {
                    default     => undef,
                    implied     => undef,
                    placeholder => undef,
                    required    => 'fix',
                    type        => "string",
                },
            };
            $a->{pvid}{required}       = \${ $a->{id}{required} };
            $a->{taggedVlan}{required} = \${ $a->{ip}{required} };
            $a->{trunkPort}{required}  = \${ $a->{ip}{required} };
            $a;
        }
    );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
