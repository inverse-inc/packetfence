#!/usr/bin/perl

=head1 NAME

ui_plugins

=head1 DESCRIPTION

unit test for pf::ui_plugins, the registry of the admin UI plugins. The
registrations to accept and refuse are shared with the Go accessors
(go/uiplugins/testdata/registrations.json).

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More;
use JSON::MaybeXS qw(decode_json);
use File::Slurp qw(read_file);
use pf::error qw(is_success is_error);
use pf::db;
use pf::dal::ui_plugin;
use pf::ui_plugins;

my $dbh = eval { db_connect() };
BAIL_OUT("Cannot connect to dbh") unless $dbh;

my $fixture = decode_json(scalar read_file('/usr/local/pf/go/uiplugins/testdata/registrations.json'));

sub clear {
    pf::dal::ui_plugin->remove_items(-where => {});
}
clear();

for my $r (@{$fixture->{valid}}) {
    my ($ok, $error) = pf::ui_plugins::validate($r);
    ok($ok, "valid $r->{name} $r->{host} $r->{port}") or diag($error);
}

for my $r (@{$fixture->{invalid}}) {
    my ($ok) = pf::ui_plugins::validate($r);
    ok(!$ok, "invalid '$r->{name}' '$r->{host}' $r->{port}");
    my ($status) = pf::ui_plugins::register($r);
    is($status, $STATUS::UNPROCESSABLE_ENTITY, "invalid '$r->{name}' '$r->{host}' $r->{port} not registered");
}

my ($status, $error) = pf::ui_plugins::register({ name => 'acme', host => 'acme', port => 8080 });
ok(is_success($status), 'register') or diag($error);
($status, $error) = pf::ui_plugins::register({ name => 'acme', host => 'acme', port => '8081' });
ok(is_success($status), 'register again, an update') or diag($error);
($status) = pf::ui_plugins::register({ name => 'other', host => '10.0.0.1', port => 80 });
ok(is_success($status), 'register another plugin');

is_deeply(pf::ui_plugins::get('acme'), { name => 'acme', host => 'acme', port => 8081 }, 'get');
is(pf::ui_plugins::get('unknown'), undef, 'get an unknown plugin');

my ($found, $row) = pf::dal::ui_plugin->find({ name => 'acme' });
is_deeply({ map { $_ => $row->{$_} } qw(name host port) }, { name => 'acme', host => 'acme', port => 8081 }, 'the row of the Go accessors');

# rows written by hand that are not valid registrations
pf::dal::ui_plugin->new({ name => 'bad', host => 'x y', port => 1 })->insert;
pf::dal::ui_plugin->new({ name => 'Upper', host => 'h', port => 1 })->insert;
pf::dal::ui_plugin->new({ name => 'zero', host => 'h', port => 0 })->insert;
is(pf::ui_plugins::get('bad'), undef, 'get an invalid row');
is_deeply(
    pf::ui_plugins::list(),
    {
        acme  => { name => 'acme', host => 'acme', port => 8081 },
        other => { name => 'other', host => '10.0.0.1', port => 80 },
    },
    'list skips the invalid rows'
);

($status) = pf::ui_plugins::deregister('acme');
is($status, $STATUS::OK, 'deregister');
($status) = pf::ui_plugins::deregister('acme');
is($status, $STATUS::OK, 'deregister an unknown plugin');
is(pf::ui_plugins::get('acme'), undef, 'deregistered');

clear();
done_testing();

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
