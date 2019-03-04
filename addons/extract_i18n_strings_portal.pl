#!/usr/bin/perl -w

=head1 NAME

extract_i18n_strings.pl - extract localizable strings

=head1 SYNOPSIS

=head1 DESCRIPTION

The script extracts the strings from the source code and the HTML templates that
can be localized.

=cut

use File::Find;
use lib qw(/usr/local/pf/lib);
use pf::web::constants;
use pf::person;

use constant {
    CONF => 'conf',
    PORTAL => 'html/captive-portal/templates'
};

my %strings = ();
my %translations = ();

=head1 SUBROUTINES

=head2 add_string

Add a localizable sring to the list.

=cut

sub add_string {
    my ($string, $source) = @_;

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
    my $file = 'conf/locale/en/LC_MESSAGES/packetfence.po';

    my ($key, %msg);
    open (PO, $file);
    my $line;
    while (defined($line = <PO>)) {
        chomp $line;
        if ($line =~ m/^\s*\"(.+)\"$/) {
            if ($key) {
                $msg{$key} .= $1;
            }
        }
        elsif ($line =~ m/^(msgid|msgstr) \"(.*)\"$/) {
            if ($msg{msgid} && $msg{msgstr}) {
                add_translation($msg{msgid}, $msg{msgstr});
                delete $msg{msgid};
                delete $msg{msgstr};
            }
            elsif ($1 eq 'msgid') {
                delete $msg{msgstr};
            }
            $key = $1;
            $msg{$key} = $2;
        }
    }
    if ($msg{msgid} && $msg{msgstr}) {
        add_translation($msg{msgid}, $msg{msgstr});
    }
}

=head2 parse_tt

Extract localizable strings from TT templates.

=cut

sub parse_tt {
    my $dir = PORTAL;
    my @templates = ();

    my $tt = sub {
        return unless -f && m/\.(html)$/;
        push(@templates, $File::Find::name);
    };

    find($tt, $dir);

    my $line;
    foreach my $template (@templates) {
        open(TT, $template);
        while (defined($line = <TT>)) {
            chomp $line;
            while ($line =~ m/i18n(_format)?\(['"](.+?(?!\\))['"](,.*)?\)/g) {
                add_string($2, $template) unless ($2 =~ m/\${/);
            }
        }
        close(TT);
    }
}

=head2 parse_mc

Extract localizable strings from Models and Controllers classes.

=cut

sub parse_mc {
    my @modules = ('lib/pf/web.pm');
    my @dir = qw(lib/pf/web html/captive-portal/lib/captiveportal/PacketFence/Controller html/captive-portal/lib/captiveportal/PacketFence/DynamicRouting html/captive-portal/lib/captiveportal/PacketFence/Form);

    my $pm = sub {
        return unless -f && m/\.pm$/;
        push(@modules, $File::Find::name);
    };

    foreach my $base (@dir) {
        find($pm, $base);
    }

    my $line;
    foreach my $module (@modules) {
        open(PM, $module);
        $module =~ s/^\.\///;
        while (defined($line = <PM>)) {
            chomp $line;
            if ($line =~ m/i18n(_format)?\(['"]([^\$].+?[^'"\\])["']\)/) {
                my $string = $2;
                $string =~ s/\\'/'/g;
                add_string($string, $module);
            } elsif ($line =~ m/i18n(_format)?\(['"](.+?)["']/) {
                my $string = $2;
                $string =~ s/\\'/'/g;
                add_string($string, $module);
            } elsif ($line =~ m/(title|message|label)'?\s+=>\s+['"]([^\$].+?[^'"\\])["']/) {
                my $string = $2;
                $string =~ s/\\'/'/g;
                add_string($string, $module);
            } elsif ($line =~ m/showError\((?:\$c,)?\s?['"]([^\$].+?[^'"\\])["']/) {
                my $string = $1;
                $string =~ s/\\'/'/g;
                add_string($string, $module);
            }
        }
        close(PM);
    }
}

=head2 extract_modules

Extract various localizable strings from PacketFence modules.

=cut

sub extract_modules {
    my %strings = ();

    sub const {
        my ($module, $name, $arrayref) = @_;

        foreach (@$arrayref) {
            add_string($_, "$module ($name)");
        }
    }

    const('pf::web::constants', 'Locales', \@WEB::LOCALES);
}

=head2 parse_person

Extract pf::person::FIELDS with the first caracter as upper

=cut

sub parse_person {
    foreach my $field (@pf::person::FIELDS){
        add_string(ucfirst($field),'pf::person::FIELDS');
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
"POT-Creation-Date: YEAR-MO-DA HO:MI+ZONE\\n"
"PO-Revision-Date: $now\\n"
"Last-Translator: Inverse inc. <info\@inverse.ca>\\n"
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
&parse_tt;
&parse_person;
&parse_mc;
&extract_modules;
&print_po;
&verify;

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

