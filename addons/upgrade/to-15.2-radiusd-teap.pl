#!/usr/bin/perl

=head1 NAME

to-15.2-radiusd-teap.pl

=head1 DESCRIPTION

Patch in-place radiusd templates that ship as %config(noreplace) so existing
installations pick up the EAP-TEAP support added in 15.2:

  - conf/radiusd/eap.conf       : add the [% ELSIF eaptype == "TEAP" %] block
                                  before the FAST elsif, sourced from
                                  eap.conf.example.
  - conf/radiusd/mschap.conf    : add the `mschap chrooted_mschap_mppe { ... }`
                                  module block referenced by
                                  raddb/policy.d/packetfence (TEAP + Domain
                                  inner MSCHAPv2 path).
  - conf/radiusd/teap.conf      : ensure the file exists (touch if missing).

The script is idempotent: re-running it after a successful pass is a no-op.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use File::Copy qw(copy);
use POSIX qw(strftime);

use pf::util;
run_as_pf();

my $CONF_DIR = '/usr/local/pf/conf/radiusd';
my $STAMP    = strftime('%Y%m%d%H%M%S', localtime);

my ($pf_uid, $pf_gid) = (getpwnam('pf'))[2,3];

my $changes = 0;

$changes += patch_eap_conf();
$changes += patch_mschap_conf();
$changes += ensure_teap_conf();

if ($changes) {
    print "Done. $changes file(s) updated.\n";
} else {
    print "Nothing to do; all radiusd TEAP blocks already present.\n";
}

exit 0;

sub patch_eap_conf {
    my $target  = "$CONF_DIR/eap.conf";
    my $source  = "$CONF_DIR/eap.conf.example";

    return 0 unless -f $target;

    my $current = slurp($target);
    if ($current =~ /\[% ELSIF eaptype == "TEAP" %\]/) {
        print "$target already contains the TEAP block; skipping.\n";
        return 0;
    }

    my $example = slurp($source);
    my ($teap_block) = $example =~ /(\[% ELSIF eaptype == "TEAP" %\].*?)(?=\[% ELSIF eaptype == "FAST" %\])/s;
    unless (defined $teap_block && length $teap_block) {
        warn "Could not extract TEAP block from $source; aborting eap.conf patch.\n";
        return 0;
    }

    unless ($current =~ /\[% ELSIF eaptype == "FAST" %\]/) {
        warn "Could not find FAST anchor in $target; aborting eap.conf patch.\n";
        return 0;
    }

    backup($target);
    $current =~ s/(\[% ELSIF eaptype == "FAST" %\])/$teap_block$1/;
    write_file($target, $current);
    print "Patched $target with EAP-TEAP block.\n";
    return 1;
}

sub patch_mschap_conf {
    my $target = "$CONF_DIR/mschap.conf";
    my $source = "$CONF_DIR/mschap.conf.example";

    return 0 unless -f $target;

    my $current = slurp($target);
    if ($current =~ /^\s*mschap\s+chrooted_mschap_mppe\s*\{/m) {
        print "$target already contains chrooted_mschap_mppe; skipping.\n";
        return 0;
    }

    my $example = slurp($source);
    my ($mppe_block) = $example =~ /(^mschap\s+chrooted_mschap_mppe\s*\{.*?^\})\s*\n/sm;
    unless (defined $mppe_block && length $mppe_block) {
        warn "Could not extract chrooted_mschap_mppe block from $source; aborting mschap.conf patch.\n";
        return 0;
    }

    backup($target);

    # Prefer inserting before chrooted_mschap_machine to keep related modules adjacent.
    if ($current =~ /^mschap\s+chrooted_mschap_machine\s*\{/m) {
        $current =~ s/(^mschap\s+chrooted_mschap_machine\s*\{)/$mppe_block\n\n$1/m;
    } else {
        $current .= "\n$mppe_block\n";
    }

    write_file($target, $current);
    print "Patched $target with chrooted_mschap_mppe block.\n";
    return 1;
}

sub ensure_teap_conf {
    my $target = "$CONF_DIR/teap.conf";
    return 0 if -e $target;

    open(my $fh, '>', $target) or do {
        warn "Could not create $target: $!\n";
        return 0;
    };
    close($fh);
    chown $pf_uid, $pf_gid, $target if defined $pf_uid;
    print "Created empty $target (user-defined TEAP profiles will be appended here).\n";
    return 1;
}

sub slurp {
    my ($path) = @_;
    open(my $fh, '<', $path) or die "Cannot read $path: $!";
    local $/;
    my $content = <$fh>;
    close($fh);
    return $content;
}

sub write_file {
    my ($path, $content) = @_;
    open(my $fh, '>', $path) or die "Cannot write $path: $!";
    print $fh $content;
    close($fh);
    chown $pf_uid, $pf_gid, $path if defined $pf_uid;
}

sub backup {
    my ($path) = @_;
    my $bak = "$path.before-15.2.$STAMP";
    copy($path, $bak) or die "Cannot back up $path -> $bak: $!";
    chown $pf_uid, $pf_gid, $bak if defined $pf_uid;
    print "Backed up $path -> $bak\n";
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
