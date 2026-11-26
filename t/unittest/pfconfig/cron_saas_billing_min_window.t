#!/usr/bin/perl

=head1 NAME

cron_saas_billing_min_window

=head1 DESCRIPTION

pfconfig::namespaces::config::Cron::build_child: in SaaS (PF_SAAS) the window
of node_meta_billing_retention cannot go under 60 days — doing so would prune
node_meta rows for the current month's billing cycle before the cycle ends.
Other tasks are untouched.

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 11;
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
    node_meta_billing_retention => '30D',
    radius_audit_log_cleanup    => '1D',
    auth_log_cleanup            => '45D',
);

{
    local $ENV{PF_SAAS};
    delete $ENV{PF_SAAS};
    my $result = build(%windows);
    is($result->{node_meta_billing_retention}{window}, 30 * $DAY, 'on-premises: node_meta_billing_retention window is kept');
    is($result->{radius_audit_log_cleanup}{window},    $DAY,       'on-premises: radius_audit_log_cleanup window is kept');
    is($result->{auth_log_cleanup}{window},            45 * $DAY,  'on-premises: auth_log_cleanup window is kept');
}

{
    local $ENV{PF_SAAS} = 'no';
    is(build(%windows)->{node_meta_billing_retention}{window}, 30 * $DAY, 'PF_SAAS=no: node_meta billing window is kept');
}

{
    local $ENV{PF_SAAS} = 'yes';
    my $result = build(%windows);
    is($result->{node_meta_billing_retention}{window}, 60 * $DAY, 'SaaS: node_meta_billing_retention window is raised to 60 days');
    is($result->{radius_audit_log_cleanup}{window},    $DAY,      'SaaS: radius_audit_log_cleanup window is NOT touched (forensic-only)');
    is($result->{auth_log_cleanup}{window},            45 * $DAY, 'SaaS: auth_log_cleanup window is NOT touched (forensic-only)');

    $result = build(node_meta_billing_retention => '1Y');
    is($result->{node_meta_billing_retention}{window}, 365 * $DAY, 'SaaS: a longer window is kept');

    $result = build(node_meta_billing_retention => '60D');
    is($result->{node_meta_billing_retention}{window}, 60 * $DAY, 'SaaS: the minimum itself is kept');
}

# The default covers the current month + prior billable month
my $defaults = pf::IniFiles->new(-file => $cron_default_config_file, -envsubst => 1);
is(normalize_time($defaults->val('node_meta_billing_retention', 'window')), 60 * $DAY, 'node_meta_billing_retention default window is 60 days');

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
