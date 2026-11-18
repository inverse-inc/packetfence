#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;

my $root = "$FindBin::Bin/../..";
plan skip_all => 'Run from a source checkout containing Debian and RPM packaging files'
    unless -f "$root/debian/packetfence.postinst" && -f "$root/rpm/packetfence.spec";
my $tmp = tempdir(CLEANUP => 1);
open my $stub, '>', "$tmp/pfcmd" or die $!;
print {$stub} <<'SH';
#!/bin/sh
printf '%s|%s\n' "${PF_SKIP_SYSTEMD_TARGET_PROMOTION-}" "$*"
exit "${PF_TEST_COMMAND_STATUS:-0}"
SH
close $stub or die $!;
chmod 0755, "$tmp/pfcmd" or die $!;

for my $package (
    { file => 'debian/packetfence.postinst', fresh => ['configure'], upgrade => ['configure', '15.2.0'] },
    { file => 'rpm/packetfence.spec', fresh => ['1'], upgrade => ['2'] },
) {
    subtest $package->{file} => sub {
        open my $input, '<', "$root/$package->{file}" or die $!;
        my $source = do { local $/; <$input> };
        close $input;
        # Execute the real updatesystemd branch, replacing only pfcmd. Never run
        # the rest of a package installer against the test machine.
        my ($branch) = $source =~ m{
            (^[\t ]*if[^\n]+\n
             [\t ]*(?:PF_SKIP_SYSTEMD_TARGET_PROMOTION=1[\t ]+)?/usr/local/pf/bin/pfcmd[\t ]+service[\t ]+pf[\t ]+updatesystemd\n
             [\t ]*else\n
             [\t ]*(?:PF_SKIP_SYSTEMD_TARGET_PROMOTION=1[\t ]+)?/usr/local/pf/bin/pfcmd[\t ]+service[\t ]+pf[\t ]+updatesystemd\n
             [\t ]*fi)
        }mx;
        ok(defined $branch, 'installer distinguishes fresh install and upgrade updates');
        return unless defined $branch;
        $branch =~ s{/usr/local/pf/bin/pfcmd}{"$tmp/pfcmd"}g;
        open my $script, '>', "$tmp/installer.sh" or die $!;
        print {$script} "$branch\n";
        close $script or die $!;

        for my $mode (qw(fresh upgrade)) {
            for my $command_status (0, 7) {
                local $ENV{PF_SKIP_SYSTEMD_TARGET_PROMOTION};
                delete $ENV{PF_SKIP_SYSTEMD_TARGET_PROMOTION};
                local $ENV{PF_TEST_COMMAND_STATUS} = $command_status;
                open my $output, '-|', '/bin/sh', "$tmp/installer.sh", @{$package->{$mode}} or die $!;
                my $result = do { local $/; <$output> };
                close $output;
                is($? >> 8, $command_status, "$mode branch retains command status");
                is($result, ($mode eq 'upgrade' ? '1' : '') . "|service pf updatesystemd\n",
                    "$mode passes the intended promotion policy and arguments");
            }
        }
    };
}

subtest 'full upgrade preserves the boot target' => sub {
    open my $input, '<', "$root/addons/full-upgrade/run-upgrade.sh" or die $!;
    my $source = do { local $/; <$input> };
    close $input;
    my @commands = $source =~ m{^([^\n]*/usr/local/pf/bin/pfcmd\s+service\s+pf\s+updatesystemd[^\n]*)$}mg;
    is(scalar @commands, 1, 'full upgrade has one unit-update call');
    for my $command (@commands) {
        $command =~ s{/usr/local/pf/bin/pfcmd}{"$tmp/pfcmd"};
        for my $command_status (0, 7) {
            local $ENV{PF_SKIP_SYSTEMD_TARGET_PROMOTION};
            delete $ENV{PF_SKIP_SYSTEMD_TARGET_PROMOTION};
            local $ENV{PF_TEST_COMMAND_STATUS} = $command_status;
            open my $output, '-|', '/bin/sh', '-c', $command or die $!;
            my $result = do { local $/; <$output> };
            close $output;
            is($? >> 8, $command_status, 'unit-update call retains command status');
            is($result, "1|service pf updatesystemd\n", 'full upgrade suppresses promotion');
        }
    }
};
done_testing;
