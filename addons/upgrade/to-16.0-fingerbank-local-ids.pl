#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-16.0-fingerbank-local-ids.pl

=cut

=head1 DESCRIPTION

Clean up the settings that reference a local Fingerbank entry (an ID that starts
with L, ex: L12). The local Fingerbank database was removed in 16.0: these IDs
don't exist anymore and never match. The admin interface also refuses to save
a setting that still holds one.

A reference is removed only when removing it doesn't change what the setting
matches now that the IDs are gone:

=over

=item * Security event triggers: a trigger that requires a local entry
(device, DHCP fingerprint, DHCP vendor, DHCPv6 fingerprint, DHCPv6 enterprise,
MAC vendor) can never match: it is removed. A device_is_not condition on a local
entry is always true: it is removed from the conditions it is combined with.

=item * Device lists where an empty list matches every device (provisioner and
scan engine OSes, self service allowed devices, network behavior policy included
devices): the local IDs are removed when the list still has other IDs.

=item * Excluded devices (network behavior policies): the local IDs are removed.

=item * Device class transitions (fingerbank_device_change): the transitions
that use a local ID are removed.

=back

The other references are left as they are and reported: removing them would
change what the setting matches (ex: a provisioner whose OSes are all local
entries would then match every device). Review and fix them.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::util;
use pf::file_paths qw(
    $security_events_config_file
    $provisioning_config_file
    $scan_config_file
    $self_service_config_file
    $network_behavior_policy_config_file
    $pf_config_file
);

# The trigger types that match a Fingerbank ID
our $MATCH_TRIGGER_TYPES = qr/device|dhcp_fingerprint|dhcp_vendor|dhcp6_fingerprint|dhcp6_enterprise|mac_vendor/i;
our $NOT_TRIGGER_TYPES = qr/device_is_not/i;
our $LOCAL_ID = qr/L\d+/i;

main() if not caller();

sub main {
    run_as_pf();
    my @results = clean_local_fingerbank_ids(config_files());
    print_results(@results);
}

=head2 config_files

The configuration files to check, with how each one stores Fingerbank IDs

=cut

sub config_files {
    return (
        { file => $security_events_config_file, keys => ['trigger'], format => 'trigger' },
        { file => $provisioning_config_file, keys => ['oses'], format => 'included' },
        { file => $scan_config_file, keys => ['oses'], format => 'included' },
        { file => $self_service_config_file, keys => ['device_registration_allowed_devices'], format => 'included' },
        { file => $network_behavior_policy_config_file, keys => ['devices_included'], format => 'included' },
        { file => $network_behavior_policy_config_file, keys => ['devices_excluded'], format => 'excluded' },
        { file => $pf_config_file, sections => ['fingerbank_device_change'], keys => ['device_class_whitelist', 'triggers'], format => 'transitions' },
    );
}

=head2 clean_local_fingerbank_ids

Clean the local Fingerbank IDs of the configuration files, rewriting the files
that changed.

Returns a hashref (file, section, key, removed => [IDs], kept => [IDs], reason)
for each setting that references a local Fingerbank ID

=cut

sub clean_local_fingerbank_ids {
    my (@configs) = @_;
    my @results;
    my %inis;
    my %changed;
    for my $config (@configs) {
        my $file = $config->{file};
        next unless -f $file;
        my $ini = $inis{$file} //= pf::IniFiles->new(-file => $file, -allowempty => 1);
        next unless $ini;
        my @sections = $config->{sections} ? @{$config->{sections}} : $ini->Sections();
        for my $section (@sections) {
            for my $key (@{$config->{keys}}) {
                my $value = $ini->val($section, $key) // next;
                my $result = clean_value($value, $config->{format});
                next unless @{$result->{removed}} || @{$result->{kept}};
                if (defined $result->{value}) {
                    $ini->setval($section, $key, $result->{value});
                    $changed{$file} = 1;
                }
                push @results, { file => $file, section => $section, key => $key, %$result };
            }
        }
    }
    for my $file (sort keys %changed) {
        $inis{$file}->RewriteConfig() or die "Unable to rewrite $file";
    }
    return @results;
}

=head2 clean_value

Clean the local Fingerbank IDs of a value.

Returns a hashref:

value: the cleaned value, undef when it doesn't change

removed: the local IDs that were removed

kept: the local IDs that were left because removing them would change what the setting matches

reason: why they were left

=cut

sub clean_value {
    my ($value, $format) = @_;
    return clean_trigger($value) if $format eq 'trigger';
    return clean_transitions($value) if $format eq 'transitions';
    return clean_list($value, $format eq 'excluded');
}

sub is_local_id {
    my ($id) = @_;
    return defined($id) && $id =~ /^\s*$LOCAL_ID\s*$/;
}

sub trim_split {
    my ($separator, $value) = @_;
    return grep { $_ ne '' } map { s/^\s+|\s+$//gr } split($separator, $value);
}

sub result {
    my (%args) = @_;
    return {
        value => $args{value},
        removed => [ map { uc } @{$args{removed} // []} ],
        kept => [ map { uc } @{$args{kept} // []} ],
        reason => $args{reason},
    };
}

=head2 clean_list

A list of IDs. In an excluded list the local IDs exclude nothing: they are removed.
In an included list an empty list matches every device: the local IDs are removed
only when the list keeps other IDs.

=cut

sub clean_list {
    my ($value, $excluded) = @_;
    my @ids = trim_split(qr/,/, $value);
    my @local = grep { is_local_id($_) } @ids;
    return result() unless @local;
    my @others = grep { !is_local_id($_) } @ids;
    if (!$excluded && !@others) {
        return result(kept => \@local, reason => "it only has local entries: an empty list would match every device");
    }
    return result(value => join(',', @others), removed => \@local);
}

=head2 clean_transitions

A list of device class transitions (FROM->TO): a transition from or to a local
ID never happens, it is removed

=cut

sub clean_transitions {
    my ($value) = @_;
    my (@kept, @removed);
    for my $transition (trim_split(qr/[,\n]/, $value)) {
        my @local = grep { is_local_id($_) } split(/\s*->\s*/, $transition);
        if (@local) {
            push @removed, @local;
        } else {
            push @kept, $transition;
        }
    }
    return result() unless @removed;
    return result(value => join(',', @kept), removed => \@removed);
}

=head2 clean_trigger

The triggers of a security event: a list of triggers, each one a condition
(TYPE::VALUE) or conditions that must all match ((TYPE::VALUE&TYPE::VALUE))

=cut

sub clean_trigger {
    my ($value) = @_;
    my (@triggers, @removed, @kept);
    for my $trigger (trim_split(qr/,/, $value)) {
        my @conditions = $trigger =~ /^\((.*)\)$/ ? trim_split(qr/&/, $1) : ($trigger);
        my @match_local = map { /^(?:$MATCH_TRIGGER_TYPES)::($LOCAL_ID)$/ ? ($1) : () } @conditions;
        my @not_local = map { /^(?:$NOT_TRIGGER_TYPES)::($LOCAL_ID)$/ ? ($1) : () } @conditions;
        if (@match_local) {
            # Requires a local entry: never matches
            push @removed, @match_local, @not_local;
            next;
        }
        if (@not_local) {
            my @others = grep { !/^(?:$NOT_TRIGGER_TYPES)::$LOCAL_ID$/ } @conditions;
            if (@others) {
                # The condition on a local entry is always true
                push @removed, @not_local;
                push @triggers, @others > 1 ? "(" . join('&', @others) . ")" : $others[0];
                next;
            }
            push @kept, @not_local;
        }
        push @triggers, $trigger;
    }
    return result() unless @removed || @kept;
    if (!@triggers) {
        # Removing them all would leave a security event without triggers
        return result(kept => [ @removed, @kept ], reason => "all its triggers use a local entry: the security event can't be triggered anymore");
    }
    return result(
        value => (@removed ? join(',', @triggers) : undef),
        removed => \@removed,
        kept => \@kept,
        reason => (@kept ? "a device_is_not trigger on a local entry matches every device now" : undef),
    );
}

=head2 print_results

=cut

sub print_results {
    my (@results) = @_;
    if (!@results) {
        print "No setting references a local Fingerbank entry\n";
        return;
    }
    my $review;
    for my $r (@results) {
        my $setting = "$r->{file}: [$r->{section}] $r->{key}";
        if (@{$r->{removed}}) {
            print "$setting: removed the local Fingerbank entries " . join(', ', @{$r->{removed}}) . "\n";
        }
        if (@{$r->{kept}}) {
            print "$setting: kept the local Fingerbank entries " . join(', ', @{$r->{kept}}) . " because $r->{reason}\n";
            $review = 1;
        }
    }
    if ($review) {
        print "The local Fingerbank entries were removed and never match: review the settings that still reference one\n";
    }
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
