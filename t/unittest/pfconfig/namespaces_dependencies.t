#!/usr/bin/perl

=head1 NAME

namespaces_dependencies

=head1 DESCRIPTION

A namespace that reads another one when it is built must be declared as a
child resource of it: pfconfig::manager only rebuilds it when that namespace
expires, and after it, if it is.

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/lib);
    use test_paths;
}

use Test::More tests => 7;
use Test::NoWarnings;

use pfconfig::namespaces::config::Connector;
use pfconfig::namespaces::config::Switch;
use pfconfig::namespaces::interfaces::management_network;

# A cache that has nothing in it: only the declarations are looked at
{
    package empty_cache;
    sub new { bless {}, shift }
    sub get_cache { {} }
}

sub children {
    my ($class, @args) = @_;
    return $class->new(empty_cache->new, @args)->{child_resources} // [];
}

my $connector = children('pfconfig::namespaces::config::Connector');
for my $child (qw(resource::connectors_config resource::pfconnector_static_connections)) {
    ok((grep { $_ eq $child } @$connector), "$child is rebuilt after config::Connector");
}

ok(
    (grep { $_ eq 'config::Switch' } @{ children('pfconfig::namespaces::interfaces::management_network') }),
    'config::Switch is rebuilt after interfaces::management_network',
);

ok(
    (grep { $_ eq 'config::Switch(host1)' } @{ children('pfconfig::namespaces::interfaces::management_network', 'host1') }),
    'config::Switch(host1) is rebuilt after interfaces::management_network(host1)',
);

ok(
    !(grep { /^interfaces::management_network/ } @{ children('pfconfig::namespaces::config::Switch') }),
    'interfaces::management_network is not rebuilt after config::Switch, which reads it',
);

ok(
    !(grep { /^interfaces::management_network/ } @{ children('pfconfig::namespaces::config::Switch', 'host1') }),
    'interfaces::management_network(host1) is not rebuilt after config::Switch(host1)',
);

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
