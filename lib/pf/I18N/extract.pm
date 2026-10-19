package pf::I18N::extract;

=head1 NAME

pf::I18N::extract -

=head1 DESCRIPTION

Shared helpers of the extractors of the localizable strings
(addons/extract_i18n_strings*.pl).

A msgid must be the string looked up at runtime: a string literal read from
the source is first decoded (its escapes turned into the characters they stand
for), then escaped for the PO file.

=cut

use strict;
use warnings;

use Exporter qw(import);
use Encode qw(encode);

our @EXPORT_OK = qw(js_unescape js_translated_strings perl_unescape po_escape add_source);

# The single-character escapes of a JavaScript string literal
my %JS_ESCAPES = (
    n => "\n",
    r => "\r",
    t => "\t",
    b => "\b",
    f => "\f",
    v => "\x0B",
);

=head2 js_unescape

Decode the escapes of a JavaScript string literal (without its quotes).
Any other escaped character stands for itself, as in JavaScript.

The sources are read as UTF-8 bytes: a character given by its code point
(\u00e9, \x41) is added as its UTF-8 bytes too.

=cut

sub js_unescape {
    my ($literal) = @_;
    $literal =~ s{
        \\ (?:
            u\{([0-9A-Fa-f]+)\}        # \u{1F600}
          | u([0-9A-Fa-f]{4})          # \u00e9
          | x([0-9A-Fa-f]{2})          # \x41
          | (0)(?![0-9])               # \0
          | (\r\n|\n|\r)               # line continuation
          | (.)                        # \n, \\, \', ...
        )
    }{
        defined $1 ? _utf8_char($1)
      : defined $2 ? _utf8_char($2)
      : defined $3 ? _utf8_char($3)
      : defined $4 ? "\0"
      : defined $5 ? ''
      : exists $JS_ESCAPES{$6} ? $JS_ESCAPES{$6} : $6
    }gsex;
    return $literal;
}

sub _utf8_char {
    my ($hex) = @_;
    return encode('UTF-8', chr(hex $hex));
}

# A JavaScript string literal delimited by single quotes or backquotes. The body
# can't contain its unescaped quote, and an escape is a backslash and the
# character after it, so 'C:\\' ends at its last quote.
my $JS_LITERAL = qr/(?:'((?:[^\\']|\\.)*)'|`((?:[^\\`]|\\.)*)`)/s;

=head2 js_translated_strings

The strings of a line of the admin source that are translated at runtime: the
first argument of $t() and i18n.t(), and the value of v-t, decoded. An empty
string is left out: it can't be a msgid (it is the header of a PO file).

=cut

sub js_translated_strings {
    my ($line) = @_;
    my @strings;
    while ($line =~ m/(?:\$t|i18n\.t)\(\s*$JS_LITERAL\s*[,)]/g) {
        push @strings, js_unescape($1 // $2);
    }
    while ($line =~ m/v-t="$JS_LITERAL"/g) {
        push @strings, js_unescape($1 // $2);
    }
    return grep { $_ ne '' } @strings;
}

=head2 perl_unescape

Decode the escapes of a quoted string of the Perl modules and templates: an
escaped backslash or quote. The other backslashes are kept as is, as in a
single-quoted Perl string.

=cut

sub perl_unescape {
    my ($literal) = @_;
    $literal =~ s/\\([\\'"])/$1/g;
    return $literal;
}

=head2 po_escape

Escape a string for a msgid or msgstr of a PO file. With newlines => 1, the
line breaks, carriage returns and tabs are escaped too: the msgid then holds
them, instead of being split on the line breaks.

=cut

sub po_escape {
    my ($string, %options) = @_;
    $string =~ s/\\/\\\\/g;
    $string =~ s/"/\\"/g;
    if ($options{newlines}) {
        $string =~ s/\n/\\n/g;
        $string =~ s/\r/\\r/g;
        $string =~ s/\t/\\t/g;
    }
    return $string;
}

=head2 add_source

Record where a string comes from, once per source

=cut

sub add_source {
    my ($strings, $string, $source) = @_;
    my $sources = $strings->{$string} //= [];
    push @$sources, $source unless grep { $_ eq $source } @$sources;
    return;
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
