#!/usr/bin/perl
=head1 NAME

useragent.t

=cut
use strict;
use warnings;
use diagnostics;

use lib '/usr/local/pf/lib';

use Test::More tests => 13;
use Test::NoWarnings;

BEGIN { use_ok('pf::useragent') }

# public calls
can_ok('pf::useragent', qw(
    view view_all add 
    property_to_tid
    process_useragent
));

# Note: these tests have no side-effects and dependencies because this module's data is self-hosted

# view_all
my @results = pf::useragent::view_all();
is(ref($results[0]), 'HASH', "view_all returns an array of hashes");

# view
is(ref(pf::useragent::view(1)), 'HASH', "view returns an hashref");

# adding
my $to_add = { id => 666, property => "test-property", description => "test description" };
ok(
    pf::useragent::add($to_add->{id}, $to_add->{property}, $to_add->{description}),
    "adding a useragent entry"
);

# verifying that adding works
is_deeply(
    pf::useragent::view($to_add->{id}),
    $to_add,
    "add worked"
);

# property_to_tid with garbage
ok(!defined(pf::useragent::property_to_tid('crap')), "property translations with string");
ok(!defined(pf::useragent::property_to_tid()), "property translations with undef");

# testing property to tid translations
my $p2t = {
    3 => "firefox",
    100 => "device",
    112 => "psp",
    405 => "vms",
};
foreach my $test (keys %{$p2t}) {
    is(pf::useragent::property_to_tid($p2t->{$test}), $test, "testing some property translations");
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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

