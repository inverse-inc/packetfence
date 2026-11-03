#!/usr/bin/perl -w

=head1 NAME

extract_i18n_strings_api.pl - extract localizable strings that are used by the API

=head1 TODO


=head1 DESCRIPTION

The script extracts the localized strings from the Javascript code and the default configuration
files.

It must be run from the root of the repository.

=head1 SYNOPSIS

  # core: html/pfappserver/root/src and conf/*.conf.defaults
  addons/extract_i18n_strings_api.pl > conf/I18N/api/en.po.tmp

  # an admin UI extension: only its own strings, the ones core already has are skipped
  addons/extract_i18n_strings_api.pl --src <extension> --po <extension>/i18n/en.po > <extension>/i18n/en.po.tmp

=head1 OPTIONS

=over

=item --src DIR

Extract the strings of the Javascript code of an admin UI extension located in
DIR (see html/pfappserver/root/extensions/README.md) instead of the core ones.
The default configuration files are not parsed and the strings already in the
core PO file are skipped.

=item --po FILE

The English PO file of the existing translations, default conf/I18N/api/en.po.

=back

=cut

# The repository's lib, after the installed one, for pf::I18N::extract
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::I18N::extract qw(js_unescape js_translated_strings po_escape add_source);
use Config::IniFiles;
use File::Find;
use Getopt::Long;

use constant {
    APP => 'html/pfappserver',
    CONF => 'conf'
};

my %strings = ();
my %translations = ();
my %core_strings = ();

my $src;
my $po_file = CONF.'/I18N/api/en.po';
GetOptions(
    'src=s' => \$src,
    'po=s'  => \$po_file,
) or die "usage: $0 [--src DIR] [--po FILE]\n";
if (defined $src) {
    $src =~ s#/+$##;
    die "$src is not a directory\n" unless -d $src;
}

=head1 SUBROUTINES

=head2 add_string

Add a localizable sring to the list.

=cut

sub add_string {
    my ($string, $source, %options) = @_;

    # A string from the JavaScript source is a literal, already decoded by
    # js_translated_strings or js_unescape: it is the string looked up at
    # runtime (e.g. 'domain\\username' is domain\username)
    my $escaped = po_escape($string, newlines => 1);
    # An extension doesn't need the strings already translated by core
    return if exists $core_strings{$escaped};
    add_source(\%strings, $escaped, $source);
}

=head2 add_translation

Add an existing English translation.

=cut

sub add_translation {
    my ($key, $value) = @_;

    return unless length $value;
    $translations{$key} = $value;
}

=head2 parse_po

Parse the English PO file to extract existing translations because some keys are
translated even for English.

=cut

sub parse_po {
    my ($file, $callback) = @_;
    $file //= $po_file;
    $callback //= \&add_translation;
    my ($key, %msg);
    open(PO, $file) or return;
    my $line;
    while (defined($line = <PO>)) {
        chomp $line;
        if ($line =~ m/^\s*\"(.+)\"$/) {
            if ($key) {
                $msg{$key} .= $1;
            }
        } elsif ($line =~ m/^(msgid|msgstr) \"(.*)\"$/) {
            if ($msg{msgid} && defined $msg{msgstr}) {
                $callback->($msg{msgid}, $msg{msgstr});
                delete $msg{msgid};
                delete $msg{msgstr};
            } elsif ($1 eq 'msgid') {
                delete $msg{msgstr};
            }
            $key = $1;
            $msg{$key} = $2;
        }
    }
    if ($msg{msgid} && defined $msg{msgstr}) {
        $callback->($msg{msgid}, $msg{msgstr});
    }
    close(PO);
}

=head2 parse_core_po

Load the strings of the core PO file, skipped when extracting an extension.

=cut

sub parse_core_po {
    parse_po(CONF.'/I18N/api/en.po', sub { $core_strings{$_[0]} = 1 });
}

=head2 parse_js

Extract localized strings from JavaScript code.

=cut

sub parse_js {
    my $dir = $src // APP.'/root/src';
    my @files = ();

    my $js = sub {
        # skip the dependencies and the git metadata of an extension
        if (-d && m/^(node_modules|\.git)$/) {
            $File::Find::prune = 1;
            return;
        }
        return unless -f && m/\.(js|vue)$/;
        push(@files, $File::Find::name);
    };

    find($js, $dir);

    my $line;
    foreach my $file (sort @files) {
        my $nb = 1;
        # the sources of an extension are relative to its directory
        my $source = $file;
        $source =~ s#^\Q$src\E/## if defined $src;
        open(JS, $file);
        while (defined($line = <JS>)) {
            chomp $line;
            # $t() and v-t inside <template>, i18n.t() inside <script>
            add_string($_, "$source:$nb") for js_translated_strings($line);
            # i18n defer inside <script>
            if ($line =~ m/['`](.+?(?<!\/\/))['`],?\s+\/\/ i18n defer$/g) {
                add_string(js_unescape($1), "$source:$nb");
            }
            # Report untranslatable strings
            while ($line =~ m/(\$t\(|v-t="|i18n\.t\()([^'`].+?)[\)"]/g) {
                my $string = $2;
                warn "Can't translate variable in $source:$nb: $string\n";
            }
            $nb++;
        }
        close(JS);
    }
}

=head2 parse_conf

Parse the default configuration files and look for the 'description' parameters.

=cut

sub parse_conf {
    my $dir = CONF;
    my @files = ();
    my $defaults = sub {
        return unless -f && m/\.conf\.defaults$/;
        push(@files, $File::Find::name);
    };
    find($defaults, $dir);
    my %ini;
    foreach my $file (@files) {
        tie %ini, 'Config::IniFiles', ( -file => $file );
        foreach my $section (keys %ini) {
            foreach my $key (keys %{$ini{$section}}) {
                if ($key =~ m/description$/) {
                    add_string($ini{$section}{$key}, "$file:[$section]/$key");
                }
            }
        }
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
# Copyright (C) Inverse inc.
# English translations for $package package.
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
            print "#: $file\n";
        }
        # add_string escapes the line breaks: a msgid is always on one line
        print "msgid \"$string\"\n";
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

if (defined $src) {
    parse_core_po();
    parse_po();
    parse_js();
} else {
    parse_po();
    parse_js();
    parse_conf();
}
print_po();
verify();

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
