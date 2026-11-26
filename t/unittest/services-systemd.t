#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More;
use pf::services;
use pf::cmd::pf::service;
use pf::UnifiedApi::Controller::Services;
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);

{
    package SystemdTestManager;
    sub new { my $class = shift; bless {@_}, $class }
    sub name { $_[0]->{name} }
    sub isManaged { $_[0]->{managed} }
    sub sysdEnable {
        my ($self) = @_;
        push @{$self->{events}}, 'enable:' . $self->name;
        return !$self->{fail};
    }
    sub sysdDisable {
        my ($self) = @_;
        push @{$self->{events}}, 'disable:' . $self->name;
        return !$self->{fail};
    }
}

for my $caller (qw(API CLI)) {
    my @cases = (
        { name => 'all updates succeed' },
        { name => 'enable fails', enable_fail => 1 },
        { name => 'disable fails', disable_fail => 1 },
        { name => 'both updates fail', enable_fail => 1, disable_fail => 1 },
        { name => 'individual service does not promote', service => 'netdata' },
    );
    push @cases, { name => 'unconfigured install keeps base target', configurator => 'enabled' };
    if ($caller eq 'CLI') {
        push @cases,
            { name => 'monit enable fails', command_fail => 'enable monit' },
            { name => 'monit disable fails', monit => 'disabled', command_fail => 'disable monit' },
            { name => 'reload fails', command_fail => 'daemon-reload' },
            { name => 'reload returns no status', missing_status => 1 },
            { name => 'upgrade keeps base target', upgrade => 1 };
    }

    for my $case (@cases) {
        subtest "$caller: $case->{name}" => sub {
            my @events;
            my @managers = (
                SystemdTestManager->new(name => 'netdata', managed => 1,
                    fail => $case->{enable_fail}, events => \@events),
                SystemdTestManager->new(name => 'snmptrapd', managed => 0,
                    fail => $case->{disable_fail}, events => \@events),
            );
            my %config = (
                advanced => { configurator => $case->{configurator} // 'disabled' },
                monit => { status => $case->{monit} // 'enabled' },
            );
            my $cluster = 0;
            my $service = $case->{service} // 'pf';
            local $ENV{PF_SKIP_SYSTEMD_TARGET_PROMOTION} = $case->{upgrade} // '';
            no warnings qw(redefine once);
            local *pf::services::Config = \%config;
            local *pf::services::cluster_enabled = \$cluster;
            local *pf::cmd::pf::service::Config = \%config;
            local $pf::cmd::pf::service::SERVICE_HEADER = '';
            local $pf::cmd::pf::service::COLORS = { success => '', error => '', reset => '' };
            local *pf::services::getManagers = sub { @managers };
            local @pf::services::ALL_SERVICES = qw(pf netdata snmptrapd);
            my $run = sub {
                my $options = pop @_;
                my $command = join(' ', @_);
                push @events, $command;
                ${$options->{status_ref}} =
                    $case->{command_fail} && $command eq "sudo systemctl $case->{command_fail}" ? 256 : 0;
                if ($case->{missing_status} && $command eq 'sudo systemctl daemon-reload') {
                    ${$options->{status_ref}} = undef;
                }
                return "packetfence-base.target\n" if $command eq 'systemctl get-default';
                return;
            };
            local *pf::services::safe_pf_run = $run;
            local *pf::cmd::pf::service::safe_pf_run = $run;

            my $failure = $case->{enable_fail} || $case->{disable_fail}
                || $case->{command_fail} || $case->{missing_status};
            my ($result, $error, $warnings, $output);
            local $SIG{__WARN__} = sub { $warnings .= shift };
            open my $stdout, '>', \$output or die $!;
            local *STDOUT = $stdout;
            if ($caller eq 'API') {
                local *pf::UnifiedApi::Controller::Services::param = sub { $service };
                local *pf::UnifiedApi::Controller::Services::_get_service_class = sub {
                    SystemdTestManager->new(name => $service);
                };
                my $controller = bless {}, 'pf::UnifiedApi::Controller::Services';
                $result = eval { $controller->do_update_systemd() };
                $error = $@;
                if ($failure) {
                    like($error, qr/Unable to update systemd/, 'unit failure reaches API error handling');
                    like($error, qr/netdata/, 'failed enable is identified') if $case->{enable_fail};
                    like($error, qr/snmptrapd/, 'failed disable is identified') if $case->{disable_fail};
                } else {
                    is($error, '', 'API succeeds');
                    is($result->{message}, "Updated systemd for $service", 'API reports success');
                }
            } else {
                $result = pf::cmd::pf::service::updateSystemd($service, qw(netdata snmptrapd));
                is($result, $failure ? $EXIT_FAILURE : $EXIT_SUCCESS, 'CLI returns the update result');
                like($warnings, qr/Unable to update systemd/, 'failure is reported') if $failure;
                ok(grep($_ eq 'sudo systemctl daemon-reload', @events), 'reload is attempted');
            }

            is_deeply([@events[0, 1]], ['enable:netdata', 'disable:snmptrapd'],
                'all units are updated even if an earlier update fails');
            my $promotes = !$failure && $service eq 'pf' && !$case->{upgrade}
                && ($case->{configurator} // '') ne 'enabled';
            my @promotion = grep { /systemctl (?:get-default|set-default)/ } @events;
            is_deeply(\@promotion, $promotes ? [
                'systemctl get-default', 'sudo systemctl set-default packetfence.target',
            ] : [], 'promotion happens only after successful updates and when permitted');
            is($events[-1], 'sudo systemctl set-default packetfence.target',
                'promotion is the final command') if $promotes;
        };
    }
}

subtest 'CLI dispatch stops when preliminary unit updates fail' => sub {
    no warnings qw(redefine once);
    for my $status ($EXIT_FAILURE, $EXIT_SUCCESS) {
        my $called = 0;
        local *pf::cmd::pf::service::updateSystemd = sub { $status };
        local *pf::util::console::colors = sub { { status => '', reset => '' } };
        local %pf::cmd::pf::service::ACTION_MAP = (start => sub { $called++; $EXIT_SUCCESS });
        my $command = bless {service => 'pf', services => ['pf'], action => 'start'}, 'pf::cmd::pf::service';
        my $output;
        open my $stdout, '>', \$output or die $!;
        local *STDOUT = $stdout;
        is($command->_run(), $status, 'preliminary failure reaches the command caller');
        is($called, $status == $EXIT_SUCCESS ? 1 : 0, 'start runs only after successful updates');
    }
};

done_testing;
