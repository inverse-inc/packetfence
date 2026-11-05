#!/usr/bin/perl

=head1 NAME

radiusd_conf_ascii

=head1 DESCRIPTION

The FreeRADIUS config templates must be plain ASCII. FreeRADIUS only strips
ASCII whitespace, so a stray non-ASCII byte (e.g. a U+00A0 no-break space
pasted into an ntlm_auth continuation line) ends up inside the argument and
breaks the command.

=cut

use strict;
use warnings;

use Test::More;

my $dir = '/usr/local/pf/conf/radiusd';
my @files = sort grep { -f } glob("$dir/*.example"), glob("$dir/*.defaults");

plan tests => scalar @files;

for my $file (@files) {
    open(my $fh, '<:raw', $file) or die "Can't open $file: $!";
    my @bad;
    while (my $line = <$fh>) {
        push @bad, $. if $line =~ /[^\x00-\x7F]/;
    }
    close($fh);
    ok(!@bad, "only ASCII in $file") or diag("non-ASCII bytes on line(s): @bad");
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
