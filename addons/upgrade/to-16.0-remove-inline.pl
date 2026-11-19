#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-16.0-remove-inline.pl

=cut

=head1 DESCRIPTION

Inline enforcement (L2 and L3) has been removed from PacketFence. This script removes
what is left of it in the configuration:

=over

=item pf.conf: the [inline] section is removed. The interfaces with an inline
enforcement lose their enforcement parameter, they are not enforcement
interfaces anymore (a warning is printed for each of them).

=item networks.conf: the networks of type inlinel2, inlinel3 and inline are removed, and the
inline only parameters (split_network, nat_enabled, nat_dns, fake_mac_enabled, coa) are removed
from the other networks.

=item switches.conf: inlineTrigger, inlineVlan and inlineRole are removed from every section.

=item dns_filters.conf: the inline scope is removed from the rules.

=item vlan_filters.conf, radius_filters.conf and switch_filters.conf: a warning is
printed for each rule using wasInline, InlineRole or _inlineTrigger. These rules
are left untouched, they have to be reviewed manually.

=back

The script is idempotent: running it again after a successful pass is a no-op.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw(
    $pf_config_file
    $network_config_file
    $switches_config_file
    $dns_filters_config_file
    $vlan_filters_config_file
    $radius_filters_config_file
    $switch_filters_config_file
);
use pf::util;

our @SWITCH_INLINE_PARAMS = qw(inlineTrigger inlineVlan inlineRole);
our @NETWORK_INLINE_PARAMS = qw(split_network nat_enabled nat_dns fake_mac_enabled coa);
our $FILTER_INLINE_RE = qr/(wasInline|InlineRole|_inlineTrigger)/;

main() if not caller();

sub main {
    run_as_pf();
    my $changes = 0;
    $changes += remove_from_pf_conf($pf_config_file);
    $changes += remove_inline_networks($network_config_file);
    $changes += remove_from_switches($switches_config_file);
    $changes += remove_from_dns_filters($dns_filters_config_file);
    my $warnings = 0;
    for my $file ($vlan_filters_config_file, $radius_filters_config_file, $switch_filters_config_file) {
        $warnings += warn_on_filters($file);
    }
    if ($changes || $warnings) {
        print("Inline enforcement removal: $changes change(s) done, $warnings warning(s)\n");
    } else {
        print("Nothing to do, no inline configuration found\n");
    }
    return 0;
}

=head2 load_ini

Load an ini file, returns undef if the file does not exist

=cut

sub load_ini {
    my ($file) = @_;
    return undef unless defined $file && -e $file;
    return pf::IniFiles->new(-file => $file, -allowempty => 1);
}

=head2 remove_from_pf_conf

Remove the [inline] section and the inline enforcement of the interfaces

=cut

sub remove_from_pf_conf {
    my ($file) = @_;
    my $ini = load_ini($file) or return 0;
    my $changes = 0;
    for my $section ($ini->Sections()) {
        next unless $section =~ /^interface (.+)$/;
        my $name = $1;
        my $enforcement = $ini->val($section, 'enforcement');
        next unless defined $enforcement && $enforcement =~ /^\s*inline/i;
        $ini->delval($section, 'enforcement');
        print("pf.conf: removed enforcement=$enforcement from $section. WARNING: interface $name is not an enforcement interface anymore, set enforcement=vlan (or dns) on it if it must be one\n");
        $changes++;
    }
    if ($ini->SectionExists('inline')) {
        $ini->DeleteSection('inline');
        print("pf.conf: removed the [inline] section\n");
        $changes++;
    }
    $ini->RewriteConfig() if $changes;
    return $changes;
}

=head2 remove_inline_networks

Remove the networks of type inline from networks.conf and the inline only parameters from the other networks

=cut

sub remove_inline_networks {
    my ($file) = @_;
    my $ini = load_ini($file) or return 0;
    my $changes = 0;
    for my $section ($ini->Sections()) {
        my $type = $ini->val($section, 'type');
        if (defined $type && $type =~ /^\s*inline/i) {
            $ini->DeleteSection($section);
            print("networks.conf: removed the network $section of type $type\n");
            $changes++;
            next;
        }
        for my $param (@NETWORK_INLINE_PARAMS) {
            next unless $ini->exists($section, $param);
            $ini->delval($section, $param);
            print("networks.conf: removed $param from [$section]\n");
            $changes++;
        }
    }
    $ini->RewriteConfig() if $changes;
    return $changes;
}

=head2 remove_from_switches

Remove inlineTrigger, inlineVlan and inlineRole from every section of switches.conf

=cut

sub remove_from_switches {
    my ($file) = @_;
    my $ini = load_ini($file) or return 0;
    my $changes = 0;
    for my $section ($ini->Sections()) {
        for my $param (@SWITCH_INLINE_PARAMS) {
            next unless $ini->exists($section, $param);
            my $value = $ini->val($section, $param);
            $ini->delval($section, $param);
            print("switches.conf: removed $param" . (defined $value && length $value ? " = $value" : "") . " from [$section]\n");
            $changes++;
        }
    }
    $ini->RewriteConfig() if $changes;
    return $changes;
}

=head2 remove_from_dns_filters

Remove the inline scope from the rules of dns_filters.conf

=cut

sub remove_from_dns_filters {
    my ($file) = @_;
    my $ini = load_ini($file) or return 0;
    my $changes = 0;
    for my $section ($ini->Sections()) {
        my $scopes = $ini->val($section, 'scopes');
        next unless defined $scopes;
        my @scopes = split(/\s*,\s*/, $scopes);
        next unless grep { lc($_) eq 'inline' } @scopes;
        my @kept = grep { lc($_) ne 'inline' } @scopes;
        if (@kept) {
            $ini->setval($section, 'scopes', join(',', @kept));
            print("dns_filters.conf: removed the inline scope from [$section], scopes are now " . join(',', @kept) . "\n");
        } else {
            $ini->delval($section, 'scopes');
            print("dns_filters.conf: removed the inline scope from [$section]. WARNING: the rule has no scope anymore, review it\n");
        }
        $changes++;
    }
    $ini->RewriteConfig() if $changes;
    return $changes;
}

=head2 warn_on_filters

Print a warning for every line of a filter file using wasInline, InlineRole or _inlineTrigger.
The file is not modified. Returns the number of warnings.

=cut

sub warn_on_filters {
    my ($file) = @_;
    return 0 unless defined $file && -e $file;
    open(my $fh, '<', $file) or do {
        print("WARNING: unable to read $file: $!\n");
        return 0;
    };
    my $warnings = 0;
    my $section = '';
    my $line_no = 0;
    while (my $line = <$fh>) {
        $line_no++;
        if ($line =~ /^\s*\[([^\]]+)\]/) {
            $section = $1;
        }
        next if $line =~ /^\s*[#;]/;
        if ($line =~ $FILTER_INLINE_RE) {
            my $what = $1;
            print("WARNING: $file line $line_no" . (length $section ? " in [$section]" : "") . " uses $what, inline enforcement was removed: review this rule\n");
            $warnings++;
        }
    }
    close($fh);
    return $warnings;
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
