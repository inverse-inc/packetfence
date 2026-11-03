#!/usr/bin/perl
=head1 NAME

trojan-source.t

=head1 DESCRIPTION

Ensure the source tree contains no Unicode bidirectional control or invisible
characters, which can be abused to make reviewed code differ from what the
compiler or the shell sees (CVE-2021-42574 "Trojan Source").

Every regular text file of the tree is scanned, whatever its extension
(scripts without one, Dockerfiles, FreeRADIUS configuration, documentation
snippets...). Look-alike letters from other scripts (homoglyphs,
CVE-2021-42694) are not detected.

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

# UTF-8 byte sequences of the bidirectional and invisible characters:
# U+202A..U+202E (LRE, RLE, PDF, LRO, RLO), U+2066..U+2069 (LRI, RLI, FSI, PDI),
# U+200B (ZWSP), U+200E/U+200F (LRM, RLM), U+2060 (WJ), U+061C (ALM).
# Matching raw bytes keeps the test immune to files with invalid UTF-8.
my $TROJAN_RE = qr/\xE2\x80[\x8B\x8E\x8F\xAA-\xAE]|\xE2\x81[\xA0\xA6-\xA9]|\xD8\x9C/;

# runtime data, vendored CPAN modules and build output are not part of the source
my $PRUNE_RE = qr{^\Q$install_dir\E/(?:var|logs|lib_perl|\.git)$|/(?:node_modules|dist)$};

# translation catalogs are maintained by translators and may legitimately carry
# direction marks
my $SKIP_RE = qr/\.po$/;

my @offenders;
find({
    no_chdir => 1,
    wanted => sub {
        my $path = $File::Find::name;
        if (-d $path) {
            $File::Find::prune = 1 if $path =~ $PRUNE_RE;
            return;
        }
        return if -l $path || !-f _ || $path =~ $SKIP_RE;
        open(my $fh, '<:raw', $path) or return;
        local $/ = undef;
        my $content = <$fh>;
        close($fh);
        # binaries (compiled Go programs, images, archives) carry NUL bytes
        return if index(substr($content, 0, 8192), "\0") >= 0;
        return unless $content =~ $TROJAN_RE;
        my $line = 1;
        for (split /\n/, $content, -1) {
            push @offenders, "$path:$line" if /$TROJAN_RE/;
            $line++;
        }
    },
}, $install_dir);

ok(!@offenders, "no Unicode bidirectional or invisible characters in the source tree")
    or diag("Unicode bidirectional or invisible characters (CVE-2021-42574) found in:\n"
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
