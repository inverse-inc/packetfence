#!/usr/bin/perl

=head1 NAME

Pfcron_saas_min_window

=head1 DESCRIPTION

In SaaS (PF_SAAS) the forms refuse a window under 32 days for
radius_audit_log_cleanup and auth_log_cleanup, and refuse to disable
radius_configuration.record_accounting_in_sql.

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More tests => 15;
use Test::NoWarnings;

use pfappserver::Form::Config::Pfcron::radius_audit_log_cleanup;
use pfappserver::Form::Config::Pfcron::auth_log_cleanup;
use pfappserver::Form::Config::Pf;

sub window_errors {
    my ($task, $interval, $unit) = @_;
    my $class = "pfappserver::Form::Config::Pfcron::$task";
    my $form = $class->new();
    $form->process(
        posted => 1,
        params => {
            id => $task, type => $task, status => 'enabled', schedule => '@every 1m', batch => 100,
            timeout => { interval => 10, unit => 's' },
            window  => { interval => $interval, unit => $unit },
        },
    );
    return [ map { @{ $_->errors } } grep { $_->name eq 'window' } $form->error_fields ];
}

sub accounting_errors {
    my ($value) = @_;
    my $form = pfappserver::Form::Config::Pf->new(section => 'radius_configuration');
    $form->process(posted => 1, params => { id => 'radius_configuration', record_accounting_in_sql => $value });
    return [ map { @{ $_->errors } } grep { $_->name eq 'record_accounting_in_sql' } $form->error_fields ];
}

for my $task (qw(radius_audit_log_cleanup auth_log_cleanup)) {
    {
        local $ENV{PF_SAAS};
        delete $ENV{PF_SAAS};
        is_deeply(window_errors($task, 1, 'D'), [], "$task on-premises: 1D is accepted");
    }
    local $ENV{PF_SAAS} = 'yes';
    is(scalar @{ window_errors($task, 1, 'D') },  1, "$task SaaS: 1D is refused");
    is(scalar @{ window_errors($task, 1, 'M') },  1, "$task SaaS: 1M is refused");
    is_deeply(window_errors($task, 32, 'D'), [], "$task SaaS: 32D is accepted");
    is_deeply(window_errors($task, 2, 'M'),  [], "$task SaaS: 2M is accepted");
}

{
    local $ENV{PF_SAAS};
    delete $ENV{PF_SAAS};
    is_deeply(accounting_errors('disabled'), [], 'on-premises: record_accounting_in_sql can be disabled');
}

{
    local $ENV{PF_SAAS} = 'yes';
    is(scalar @{ accounting_errors('disabled') }, 1, 'SaaS: record_accounting_in_sql cannot be disabled');
    is_deeply(accounting_errors('enabled'), [], 'SaaS: record_accounting_in_sql can be enabled');
    is_deeply(accounting_errors(undef), [], 'SaaS: record_accounting_in_sql can be left to its default');
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
