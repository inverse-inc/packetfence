#!/usr/bin/perl

=head1 NAME

extract

=head1 DESCRIPTION

Unit test for pf::I18N::extract, the helpers of the extractors of the
localizable strings: a msgid must be the string looked up at runtime

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 22;
use pf::I18N::extract qw(js_unescape js_translated_strings perl_unescape po_escape add_source);

#This test will running last
use Test::NoWarnings;

# js_unescape
is(js_unescape('domain\\\\username'), 'domain\\username', 'an escaped backslash is one backslash');
is(js_unescape('line one\\nline two'), "line one\nline two", '\n is a line break');
is(js_unescape('\\r\\t\\b\\f\\v'), "\r\t\b\f\x0B", '\r, \t, \b, \f and \v');
is(js_unescape("it\\'s \\\"quoted\\\""), q{it's "quoted"}, 'escaped quotes');
is(js_unescape('Caf\\u00e9'), "Caf\xC3\xA9", '\uXXXX is the UTF-8 bytes of the character');
is(js_unescape('\\x41\\u{1F600}'), "A\xF0\x9F\x98\x80", '\xHH and \u{...}');
is(js_unescape('\\0'), "\0", '\0 is the NUL character');
is(js_unescape('\\q'), 'q', 'any other escaped character stands for itself');
is(js_unescape("one \\\ntwo"), 'one two', 'a line continuation is removed');

# js_translated_strings
is_deeply([js_translated_strings(q{$t('C:\\\\') + x + $t('Other')})], ['C:\\', 'Other'], 'a literal ending with an escaped backslash ends at its quote');
is_deeply([js_translated_strings(q{{{ $t('It\\'s ok', { a: 1 }) }}})], ["It's ok"], '$t() with an escaped quote and arguments');
is_deeply([js_translated_strings(q{<span v-t="'Line\\nbreak'"/>})], ["Line\nbreak"], 'v-t');
is_deeply([js_translated_strings(q{label: i18n.t(`Backquoted 'string'`),})], ["Backquoted 'string'"], 'i18n.t() with a backquoted string');
is_deeply([js_translated_strings(q{{{ $t(' Delete' ) }}})], [' Delete'], 'spaces around the literal');
is_deeply([js_translated_strings(q{default: i18n.t('') // Press enter})], [], 'an empty string is left out');
is_deeply([js_translated_strings(q{$t(label) + $t('a' + b)})], [], 'a variable or a concatenation is not a literal to translate');

# perl_unescape
is(perl_unescape(q{it\\'s C:\\\\ and \\"q\\" \\n}), q{it's C:\\ and "q" \\n}, 'only escaped backslashes and quotes are decoded');

# po_escape
is(po_escape(qq{a\\b "c"\nd}), qq{a\\\\b \\"c\\"\nd}, 'backslashes and quotes are escaped, line breaks kept by default');
is(po_escape(qq{a\nb\r\tc}, newlines => 1), 'a\\nb\\r\\tc', 'with newlines, line breaks, carriage returns and tabs are escaped');

# add_source
my %strings;
add_source(\%strings, 'msg', 'conf/documentation.conf (section)');
add_source(\%strings, 'msg', 'conf/documentation.conf');
add_source(\%strings, 'msg', 'conf/documentation.conf');
is_deeply($strings{msg}, ['conf/documentation.conf (section)', 'conf/documentation.conf'], 'a source is recorded once, matched exactly');
add_source(\%strings, 'other', 'file.vue:1');
is_deeply([sort keys %strings], ['msg', 'other'], 'one entry per string');

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
