#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More;
use pf::UnifiedApi::Controller::Configurator;

{
    package CompletionTestNetwork;
    sub tag { $_[0]->{ip} }
    package CompletionTestManager;
    sub name { 'netdata' }
    sub isManaged { $_[0]->{managed} }
    sub optional { $_[0]->{optional} }
    sub isAlive { $_[0]->{alive} }
}

for my $case (
    { name => 'standalone completes' },
    { name => 'cluster completes', cluster => 1 },
    { name => 'custom target is preserved', target => 'multi-user.target' },
    { name => 'management is unset', no_management => 1, error => qr/management interface/ },
    { name => 'management IP is unset', no_ip => 1, error => qr/management interface/ },
    { name => 'required service is stopped', stopped => 1, error => qr/Services must be running/ },
    { name => 'optional service may be stopped', stopped => 1, optional => 1 },
    { name => 'unmanaged service may be stopped', stopped => 1, unmanaged => 1 },
    { name => 'save fails', save_fail => 1, error => qr/Unable to save/ },
    { name => 'target lookup fails', get_fail => 1, error => qr/Unable to read/ },
    { name => 'promotion fails', set_fail => 1, error => qr/Unable to set/ },
    { name => 'rollback failure is reported', set_fail => 1, rollback_fail => 1,
        error => qr/Unable to restore the configurator/ },
) {
    subtest $case->{name} => sub {
        my @events;
        my $saved = 'enabled';
        my $pending;
        my $commits = 0;
        my $default = $case->{target} // 'packetfence-base.target';
        my $original_target = $default;
        my %config = (advanced => { configurator => 'enabled' });
        my $network = $case->{no_management} ? '' : bless {
            ip => $case->{no_ip} ? '' : '192.0.2.1',
        }, 'CompletionTestNetwork';
        my $cluster = $case->{cluster} // 0;
        local $ENV{PF_SKIP_SYSTEMD_TARGET_PROMOTION} = '';
        no warnings qw(redefine once);
        local *pf::UnifiedApi::Controller::Configurator::management_network = \$network;
        local *pf::services::Config = \%config;
        local *pf::services::cluster_enabled = \$cluster;
        local *pf::services::getManagers = sub {
            return bless {
                managed => !$case->{unmanaged}, optional => $case->{optional}, alive => !$case->{stopped},
            }, 'CompletionTestManager';
        };
        local *pf::ConfigStore::Pf::new = sub { bless {}, 'pf::ConfigStore::Pf' };
        local *pf::ConfigStore::Pf::read = sub { { configurator => $saved } };
        local *pf::ConfigStore::Pf::update = sub {
            my ($self, $section, $data) = @_;
            is($section, 'advanced', 'only advanced configuration is updated');
            is_deeply([sort keys %$data], ['configurator'], 'other settings are preserved');
            $pending = $data->{configurator};
            return 1;
        };
        local *pf::ConfigStore::Pf::commit = sub {
            push @events, "save:$pending";
            $commits++;
            return (0, 'Injected rollback failure') if $case->{rollback_fail} && $commits == 2;
            $saved = $pending; # Model an initial commit that writes before reporting failure.
            return (0, 'Injected save failure') if $case->{save_fail} && $commits == 1;
            return (1, undef);
        };
        local $ENV{PF_UID} = '';
        local *pf::services::safe_pf_run = sub {
            my $options = pop @_;
            my $command = join(' ', @_);
            push @events, $command;
            ${$options->{status_ref}} = 0;
            if ($command eq 'systemctl get-default') {
                ${$options->{status_ref}} = 256 if $case->{get_fail};
                return "$default\n";
            }
            is($saved, 'disabled', 'setting is saved before promotion');
            if ($case->{set_fail}) {
                ${$options->{status_ref}} = 256;
            } else {
                $default = $_[-1];
            }
            return;
        };

        my $controller = bless {}, 'pf::UnifiedApi::Controller::Configurator';
        my $result = eval { $controller->do_complete() };
        my $error = $@;
        if ($case->{error}) {
            like($error, $case->{error}, 'failure reaches the API caller');
            is($saved, $case->{rollback_fail} ? 'disabled' : 'enabled',
                'wizard is restored for retry unless rollback itself fails');
            is($default, $original_target, 'failed completion preserves the boot target');
            is_deeply(\@events, [], 'readiness failure has no side effects')
                if $case->{no_management} || $case->{no_ip} || $case->{stopped};
            ok(!grep(/systemctl/, @events), 'save failure cannot promote') if $case->{save_fail};
        } else {
            is($error, '', 'completion succeeds');
            is($result->{message}, 'Configuration completed', 'completion is reported');
            is($saved, 'disabled', 'wizard is disabled');
            is($default, $case->{target} // ($cluster ? 'packetfence-cluster.target' : 'packetfence.target'),
                'correct boot target is retained');
            is($events[0], 'save:disabled', 'configuration is saved before target changes');
        }
    };
}

done_testing;
