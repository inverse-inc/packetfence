#!/usr/bin/perl
=head1 NAME

pf-util.pl

=head1 DESCRIPTION

Some performance benchmarks on some pf::util functions

=cut

use strict;
use warnings;
use diagnostics;

use Benchmark;

use lib '/usr/local/pf/lib';

=head1 pf::util's clean_mac 

=cut

use pf::util;

sub clean_mac_v1 {
    my ($mac) = @_;
    return (0) if ( !$mac );
    $mac =~ s/\s//g;
    $mac = lc($mac);
    $mac =~ s/\.//g if ( $mac =~ /^([0-9a-f]{4}(\.|$)){3}$/i );
    $mac =~ s/-//g if ( $mac =~ /^([0-9a-f]{4}(-|$)){3}$/i );
    $mac =~ s/([a-f0-9]{2})(?!$)/$1:/g if ( $mac =~ /^[a-f0-9]{12}$/i );
    $mac = join q {:} => map { sprintf "%02x" => hex } split m {:|\-} => $mac;
    return ($mac);
}

sub clean_mac_v2 {
    my ($mac) = @_;
    return (0) if ( !$mac );
    # trim garbage
    $mac =~ s/[\s\-\.:]//g;
    # lowercase
    $mac = lc($mac);
    # inject :
    $mac =~ s/([a-f0-9]{2})(?!$)/$1:/g if ( $mac =~ /^[a-f0-9]{12}$/i );
    return ($mac);
}

timethese(100000, {
    clean_mac_v1 => sub { 
        clean_mac_v1(undef);
        clean_mac_v1("aa-bb-cc-dd-ee-ff");
        clean_mac_v1("aa:bb:cc:dd:ee:ff");
        clean_mac_v1("aabb-ccdd-eeff");
        clean_mac_v1("aabb.ccdd.eeff");
    },
    clean_mac_v2 => sub { 
        clean_mac_v2(undef);
        clean_mac_v2("aa-bb-cc-dd-ee-ff");
        clean_mac_v2("aa:bb:cc:dd:ee:ff");
        clean_mac_v2("aabb-ccdd-eeff");
        clean_mac_v2("aabb.ccdd.eeff");
    }
});

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
