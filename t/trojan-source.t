#!/usr/bin/perl
=head1 NAME

trojan-source.t

=head1 DESCRIPTION

Ensure the source tree contains no Unicode bidirectional control or
zero-width characters, which can be abused to make reviewed code differ
from what the compiler sees (CVE-2021-42574 "Trojan Source") or to craft
homoglyph identifiers (CVE-2021-42694).

=cut

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/t);
    use setup_test_config;
}

use Test::More;
use Test::NoWarnings;
use File::Find;
use pf::file_paths qw($install_dir);

plan tests => 2;

# UTF-8 byte sequences of the characters abused by CVE-2021-42574/CVE-2021-42694:
# U+202A..U+202E (LRE, RLE, PDF, LRO, RLO), U+2066..U+2069 (LRI, RLI, FSI, PDI),
# U+200B (ZWSP), U+200E/U+200F (LRM, RLM), U+2060 (WJ), U+061C (ALM).
# Matching raw bytes keeps the test immune to files with invalid UTF-8.
my $TROJAN_RE = qr/\xE2\x80[\x8B\x8E\x8F\xAA-\xAE]|\xE2\x81[\xA0\xA6-\xA9]|\xD8\x9C/;

my @SCAN_DIRS = grep { -d $_ }
    map { "$install_dir/$_" }
    qw(addons bin sbin lib go html conf raddb src db debian rpm ci containers t tools);

# source code and configuration; translation catalogs (.po) are maintained by
# translators and may legitimately carry direction marks
my %EXTENSIONS = map { $_ => 1 }
    qw(pm pl cgi t go js vue mjml html tt css scss sh py sql yml yaml json conf example asciidoc c h);

my $PRUNE_RE = qr/\/(?:node_modules|dist|\.git)$/;

my @offenders;
find({
    no_chdir => 1,
    wanted => sub {
        my $path = $File::Find::name;
        if (-d $path && $path =~ $PRUNE_RE) {
            $File::Find::prune = 1;
            return;
        }
        return unless -f $path;
        my ($ext) = $path =~ /\.([^.\/]+)$/;
        return unless defined $ext && exists $EXTENSIONS{lc $ext};
        open(my $fh, '<:raw', $path) or return;
        local $/ = undef;
        my $content = <$fh>;
        close($fh);
        return unless $content =~ $TROJAN_RE;
        my $line = 1;
        for (split /\n/, $content, -1) {
            push @offenders, "$path:$line" if /$TROJAN_RE/;
            $line++;
        }
    },
}, @SCAN_DIRS);

ok(!@offenders, "no Unicode bidi or zero-width characters in the source tree")
    or diag("Unicode bidi/zero-width characters (CVE-2021-42574, CVE-2021-42694) found in:\n"
        . join("\n", @offenders));

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
