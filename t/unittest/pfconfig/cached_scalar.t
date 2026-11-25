#!/usr/bin/perl

=head1 NAME

cached_scalar

=head1 DESCRIPTION

Unit tests for pfconfig::cached_scalar

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use setup_test_config;
}

use Test::More tests => 6;
use Test::NoWarnings;
use pfconfig::cached_scalar;

my @requests;
my $reply;

{
    no warnings 'redefine';
    *pfconfig::cached::_get_from_socket = sub {
        my ($self, $what) = @_;
        push @requests, $what;
        return $reply;
    };
}

{
    tie my $scalar, 'pfconfig::cached_scalar', 'resource::fqdn';
    $reply = { element => 'pf.example.com' };
    @requests = ();

    is($scalar, 'pf.example.com', "FETCH returns the element of the reply");
    is(scalar @requests, 1, "FETCH queries pfconfig only once on a cache miss");
    is($requests[0], 'resource::fqdn()', "FETCH queries the tied namespace");
}

{
    tie my $scalar, 'pfconfig::cached_scalar', 'resource::fqdn';
    $reply = undef;
    @requests = ();

    is($scalar, undef, "FETCH returns undef when pfconfig has no reply");
    is(scalar @requests, 1, "FETCH queries pfconfig only once when the reply is undef");
}

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
