#!/usr/bin/perl

=head1 NAME

SelectRole

=head1 DESCRIPTION

Roles that can be selected with the SelectRole portal module

=cut

use strict;
use warnings;
BEGIN {
    use lib qw(/usr/local/pf/t /usr/local/pf/html/captive-portal/lib);
    use setup_test_config;
}

use Test::More tests => 11;
use Test::NoWarnings;

use_ok('captiveportal::PacketFence::DynamicRouting::Module::SelectRole');

# A module with fixed roles, request and node info that records what it does
{
    package test_request;
    sub new { my ($class, %params) = @_; bless {%params}, $class }
    sub param { $_[0]{$_[1]} }

    package test_app;
    sub new { my ($class, %params) = @_; bless { request => test_request->new(%params), flash => {} }, $class }
    sub request { $_[0]{request} }
    sub flash { $_[0]{flash} }

    package test_module;
    our @ISA = ('captiveportal::PacketFence::DynamicRouting::Module::SelectRole');
    sub new { my ($class, %args) = @_; bless { %args, node_info => { category => $args{category} } }, $class }
    sub admin_role { $_[0]{admin_role} }
    sub list_role { $_[0]{list_role} }
    sub app { $_[0]{app} }
    sub new_node_info { $_[0]{node_info} }
    sub description { 'Select role' }
    sub template { 'select-role.html' }
    sub done { $_[0]{done} = 1 }
    sub render { my ($self, $template, $args) = @_; $self->{rendered} = $args }
}

sub module {
    my (%params) = @_;
    return test_module->new(
        admin_role => 'admin',
        list_role  => 'admin,guest default',
        category   => 'admin',
        app        => test_app->new(%params),
    );
}

is_deeply([ module()->allowed_roles ], [qw(guest default)], 'allowed roles: list_role without admin_role, comma or space separated');

{
    my $m = test_module->new(admin_role => 'admin staff', list_role => 'admin staff guest', category => 'admin', app => test_app->new);
    is_deeply([ $m->allowed_roles ], ['guest'], 'several admin roles are all removed from the choices');
}

{
    my $m = module(new_role => 'guest');
    $m->execute_child;
    is($m->new_node_info->{category}, 'guest', 'a role of the list is applied');
    ok($m->{done}, 'and the module is done');
}

{
    my $m = module(new_role => 'gaming');
    $m->execute_child;
    is($m->new_node_info->{category}, 'admin', 'a role outside the list is not applied');
    ok(!$m->{done} && $m->{rendered}, 'the choices are shown again');
    ok($m->app->flash->{error}, 'with an error');
}

{
    my $m = module(new_role => 'admin');
    $m->execute_child;
    is($m->new_node_info->{category}, 'admin', 'an admin role is not a choice');
    ok(!$m->{done}, 'and is not applied as a choice');
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
