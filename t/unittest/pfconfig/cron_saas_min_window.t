#!/usr/bin/perl

=head1 NAME

cron_saas_min_window

=head1 DESCRIPTION

pfconfig::namespaces::config::Cron::build_child: in SaaS (PF_SAAS) the window
of radius_audit_log_cleanup and auth_log_cleanup cannot go under 32 days.

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 12;
use Test::NoWarnings;

use pf::IniFiles;
use pf::file_paths qw($cron_default_config_file);
use pf::util qw(normalize_time);
use pfconfig::namespaces::config::Cron;

my $DAY = 24 * 60 * 60;

sub build {
    my (%windows) = @_;
    my %cfg = map { $_ => { schedule => '@every 1m', batch => 100, timeout => '10s', window => $windows{$_} } } keys %windows;
    return (bless { cfg => \%cfg }, 'pfconfig::namespaces::config::Cron')->build_child();
}

my %windows = (
    radius_audit_log_cleanup => '1D',
    auth_log_cleanup         => '1W',
    acct_cleanup             => '1D',
);

{
    local $ENV{PF_SAAS};
    delete $ENV{PF_SAAS};
    my $result = build(%windows);
    is($result->{radius_audit_log_cleanup}{window}, $DAY,     'on-premises: radius_audit_log_cleanup window is kept');
    is($result->{auth_log_cleanup}{window},         7 * $DAY, 'on-premises: auth_log_cleanup window is kept');
}

{
    local $ENV{PF_SAAS} = 'no';
    is(build(%windows)->{radius_audit_log_cleanup}{window}, $DAY, 'PF_SAAS=no: window is kept');
}

{
    local $ENV{PF_SAAS} = 'yes';
    my $result = build(%windows);
    is($result->{radius_audit_log_cleanup}{window}, 32 * $DAY, 'SaaS: radius_audit_log_cleanup window is raised to 32 days');
    is($result->{auth_log_cleanup}{window},         32 * $DAY, 'SaaS: auth_log_cleanup window is raised to 32 days');
    is($result->{acct_cleanup}{window},             $DAY,      'SaaS: the window of another task is kept');

    $result = build(radius_audit_log_cleanup => '3M', auth_log_cleanup => '32D');
    is($result->{radius_audit_log_cleanup}{window}, 90 * $DAY, 'SaaS: a longer window is kept');
    is($result->{auth_log_cleanup}{window},         32 * $DAY, 'SaaS: the minimum itself is kept');
    is(build(radius_audit_log_cleanup => '1M')->{radius_audit_log_cleanup}{window}, 32 * $DAY, 'SaaS: 1M (30 days) is under a 31 days month');
}

# The defaults cover the longest month and a day to read it
my $defaults = pf::IniFiles->new(-file => $cron_default_config_file, -envsubst => 1);
for my $task (qw(radius_audit_log_cleanup auth_log_cleanup)) {
    is(normalize_time($defaults->val($task, 'window')), 32 * $DAY, "$task default window is 32 days");
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
