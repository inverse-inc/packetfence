#!/usr/bin/perl

=head1 NAME

ROUTES

=head1 DESCRIPTION

unit test for ROUTES

=cut

use strict;
use warnings;
#
use lib '/usr/local/pf/lib';

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use pf::UnifiedApi;
use List::Util qw(sum);

my $app = pf::UnifiedApi->new;

my $meta = walkRootRoutes($app->routes);
use Test::More;

#This test will running last
use Test::NoWarnings;
my @controllers = keys %{$meta->{controllers}};

plan tests => scalar @controllers + 1 + sum (map { scalar @{$_->{actions}} } values %{$meta->{controllers}});

for my $c (@controllers) {
    use_ok("pf::UnifiedApi::Controller::$c");
}

while (my ($c, $m) = each %{$meta->{controllers}}) {
    for my $a (@{$m->{actions}}) {
        ok("pf::UnifiedApi::Controller::$c"->can($a), "pf::UnifiedApi::Controller::${c}->$a exists");
    }
}

=head2 walkRootRoutes

walk the root routes

=cut

sub walkRootRoutes {
    my ($route) = @_;
    my %meta = ( 
        namespaces => $route->namespaces,
    );
    my ($root, @children) = walk( $route, \%meta);
    if (!defined $root) {
        return;
    }

    return \%meta;
}

=head2 walk

walk the routes

=cut

sub walk {
    my ($route, $meta) = @_;
    # Flags
    my $to = $route->to;
    my $action = $to->{action};
    my $controller = $to->{controller};
    my $parent = $route->parent;

    while (!defined ($controller) && defined $parent) {
        $controller = $parent->to->{controller};
        $parent = $parent->parent;
    }

    if (defined $action && !defined $controller) {
        die (($route->name // "undef") . ": An action ($action) is defined but it has no controller");
    }

    if ( $controller ) {
        if ($action) {
            push @{$meta->{controllers}{$controller}{actions}}, $action;
        }
    }

    my $children = $route->children;
    local $_;
    walk($_, $meta) for @$children;
}

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

