#!/usr/bin/perl

=head1 NAME

prune_orphaned_switch_role_mappings.pl - remove per-role switch mapping keys that reference roles that no longer exist

=head1 DESCRIPTION

Over repeated create/delete cycles of roles, switches.conf accumulates per-role
mapping keys (<role>Vlan, <role>Url, <role>Role, <role>AccessList, <role>Vpn,
<role>Interface, <role>Network, <role>NetworkFrom) for roles that have since been
deleted. These orphaned keys are never pruned, bloating switches.conf and making
the switch config API (GET /api/v1/config/switch/:id) very slow.

This script removes those orphaned keys. A role is considered valid if it is
defined in roles.conf or is one of the reserved/built-in roles.

By default it runs in DRY-RUN mode and only reports what it would delete.
Pass --commit to actually delete the keys and commit (which reloads pfconfig).

=head1 USAGE

    perl prune_orphaned_switch_role_mappings.pl            # dry-run, report only
    perl prune_orphaned_switch_role_mappings.pl --commit   # actually prune + commit

=cut

use strict;
use warnings;

use lib '/usr/local/pf/lib';
use lib '/usr/local/pf/lib_perl/lib/perl5';

use pf::ConfigStore::Switch;
use pf::ConfigStore::Roles;
use pf::constants::role qw(@ROLES %STANDARD_ROLES);

my $COMMIT = grep { $_ eq '--commit' } @ARGV;

# Per-role mapping suffixes, matching pf::ConfigStore::Switch::_expandMapping and
# Config/Roles.pm::reassign_role_config_store_switch.
my @SUFFIXES = qw(Role Url Vlan AccessList Vpn Interface Network NetworkFrom);
my $SUFFIX_RE = join('|', @SUFFIXES);

# Reserved/built-in switch role names. These are legitimate switch attributes
# shipped in switches.conf.defaults (e.g. normalVlan, macDetectionRole,
# registrationVlan, ...) and must never be pruned even though they are not
# listed in roles.conf.
my @RESERVED_ROLES = qw(
    normal registration isolation macDetection inline voice default guest gaming REJECT dmz
);

# Build the set of valid role names.
my %valid;
$valid{$_} = 1 for @{ pf::ConfigStore::Roles->new->readAllIds };
$valid{$_} = 1 for @ROLES;             # registration, isolation, inline
$valid{$_} = 1 for keys %STANDARD_ROLES; # voice, default, guest, gaming, REJECT
$valid{$_} = 1 for @RESERVED_ROLES;

printf "Valid roles: %d\n", scalar keys %valid;
print "Mode: " . ($COMMIT ? "COMMIT" : "DRY-RUN (no changes)") . "\n\n";

my $cs = pf::ConfigStore::Switch->new;
my $config = $cs->cachedConfig;

my %orphan_roles;   # role => count of keys
my $total_keys = 0;
my $changed = 0;

for my $sect ($config->Sections()) {
    my @to_delete;
    for my $param ($config->Parameters($sect)) {
        if ($param =~ /^(.+?)($SUFFIX_RE)$/) {
            my $role = $1;
            next if $valid{$role};
            push @to_delete, $param;
            $orphan_roles{$role}++;
        }
    }
    next unless @to_delete;
    $total_keys += scalar @to_delete;
    printf "[%s] %d orphaned mapping keys\n", $sect, scalar @to_delete;
    if ($COMMIT) {
        for my $param (@to_delete) {
            $config->delval($sect, $param);
            $changed = 1;
        }
    }
}

printf "\nDistinct orphaned roles: %d\n", scalar keys %orphan_roles;
printf "Total orphaned mapping keys: %d\n", $total_keys;

# Show a sample of the orphan role names so they can be eyeballed before committing.
my @sample = (sort keys %orphan_roles)[0 .. 19];
print "Sample orphaned roles:\n";
print "  $_\n" for grep { defined } @sample;

if ($COMMIT && $changed) {
    print "\nCommitting changes (this reloads the config::Switch namespace)...\n";
    $cs->commit();
    print "Done. Run 'pfcmd configreload' (soft) to refresh all services.\n";
} elsif ($COMMIT) {
    print "\nNothing to commit.\n";
} else {
    print "\nDry-run only. Re-run with --commit to apply.\n";
}
