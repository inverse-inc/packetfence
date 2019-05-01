#!/usr/bin/perl -w

=head1 NAME

extract_i18n_strings_api.pl - extract localizable strings

=head1 TODO


=head1 DESCRIPTION

The script extracts the localized strings from the Javascript code.

=cut

use File::Find;
use lib qw(/usr/local/pf/lib);

use constant {
    APP => 'html/pfappserver',
    CONF => 'conf'
};

my %strings = ();
my %translations = ();

=head1 SUBROUTINES

=head2 add_string

Add a localizable sring to the list.

=cut

sub add_string {
    my ($string, $source) = @_;

    $string =~ s/\\'/'/g; # unescape single-quotes
    $string =~ s/(?<!\\)\\/\\\\/g; # escape backslashes
    $string =~ s/(?<!\\)\"/\\\"/g; # escape double-quotes
    unless ($strings{$string}) {
        $strings{$string} = [];
    }
    unless (grep(/\Q$source\E/, @{$strings{$string}})) {
        push(@{$strings{$string}}, $source);
    }
}

=head2 add_translation

Add an existing English translation.

=cut

sub add_translation {
    my ($key, $value) = @_;

    $translations{$key} = $value;
}

=head2 parse_po

Parse the English PO file to extract existing translations because some keys are
translated even for English.

=cut

sub parse_po {
    my $file = CONF.'/I18N/api/en.po';
    my ($key, %msg);
    open(PO, $file);
    my $line;
    while (defined($line = <PO>)) {
        chomp $line;
        if ($line =~ m/^\s*\"(.+)\"$/) {
            if ($key) {
                $msg{$key} .= $1;
            }
        } elsif ($line =~ m/^(msgid|msgstr) \"(.*)\"$/) {
            if ($msg{msgid} && $msg{msgstr}) {
                add_translation($msg{msgid}, $msg{msgstr});
                delete $msg{msgid};
                delete $msg{msgstr};
            } elsif ($1 eq 'msgid') {
                delete $msg{msgstr};
            }
            $key = $1;
            $msg{$key} = $2;
        }
    }
    if ($msg{msgid} && $msg{msgstr}) {
        add_translation($msg{msgid}, $msg{msgstr});
    }
    close(PO);
}

=head2 parse_js

Extract localized strings from JavaScript code.

=cut

sub parse_js {
    my $dir = APP.'/root/static.alt/src';
    my @files = ();

    my $js = sub {
        return unless -f && m/\.(js|vue)$/;
        push(@files, $File::Find::name);
    };

    find($js, $dir);

    my $line;
    foreach my $file (@files) {
        my $nb = 1;
        open(JS, $file);
        while (defined($line = <JS>)) {
            chomp $line;
            # $t() inside <template>
            while ($line =~ m/\$t\(['`](.+?(?<!\\))['`](,.*)?\)/g) {
                my $string = $1;
                add_string($string, "$file:$nb");
            }
            # v-t inside <template>
            while ($line =~ m/v-t="['`](.+?(?<!\\))['`]"/g) {
                my $string = $1;
                add_string($string, "$file:$nb");
            }
            # i18n.t() inside <script>
            while ($line =~ m/i18n\.t\(['`](.+?(?<!\\))['`](,.*)?\)/g) {
                my $string = $1;
                add_string($string, "$file:$nb");
            }
            # Report untranslatable strings
            while ($line =~ m/(\$t\(|v-t="|i18n\.t\()([^'`].+?)[\)"]/g) {
                my $string = $2;
                warn "Can't translate variable in $file:$nb: $string\n";
            }
            $nb++;
        }
        close(JS);
    }
}

=head2 print_po

Print the PO file constructed from the extracted localizable strings.

=cut

sub print_po {
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    my $now = sprintf("%d-%02d-%02d %02d:%02d-0400", $year+1900, $mon+1, $mday, $hour, $min);

    open(RELEASE, CONF.'/pf-release');
    my $content = <RELEASE>;
    chomp $content;
    my ($package, $version) = $content =~ m/(\S+) ([\d\.]+)/;
    close(RELEASE);

    print <<EOT;
# English translations for $package package.
# Copyright (C) 2005-2019 Inverse inc.
# This file is distributed under the same license as the $package package.
#
msgid ""
msgstr ""
"Project-Id-Version: $version\\n"
"POT-Creation-Date: 2019-05-01 12:00-0400\\n"
"PO-Revision-Date: $now\\n"
"Last-Translator: Inverse inc. <support\@packetfence.org>\\n"
"Language-Team: English\\n"
"Language: en\\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8bit\\n"
"Plural-Forms: nplurals=2; plural=(n != 1);\\n"

EOT

    foreach my $string (sort keys %strings) {
        foreach my $file (sort @{$strings{$string}}) {
            print "# $file\n";
        }
        my @lines = split("\n", $string);
        if (@lines > 1) {
            print "msgid \"\"\n";
            print join("\n", map { "  \"$_\"" } @lines), "\n";
        }
        else {
            print "msgid \"$string\"\n";
        }
        print "msgstr \"" . ($translations{$string} || '') . "\"\n\n";
    }
}

=head2 verify

Check if any translated string was not extracted. In this case, we need to
manually check if the string is still used.

=cut

sub verify {
    my @translated_keys = keys %translations;
    my @extracted_keys = keys %strings;

    my %seen;
    @seen {@translated_keys} = ( );
    delete @seen {@extracted_keys};

    my @translated_not_extracted = keys %seen;
    if (scalar @translated_not_extracted) {
        warn "The following keys were not extracted:\n\t" .
          join("\n\t", sort @translated_not_extracted) .
            "\n";
    }
}

#### MAIN ####

&parse_po;
&parse_js;
&print_po;
&verify;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2019 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
