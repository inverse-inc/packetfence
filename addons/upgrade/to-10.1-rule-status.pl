#!/usr/bin/perl

=head1 NAME

to-10.1-rule-status.pl

=head1 DESCRIPTION

Upgrades the sources rules with the new "status" configuration parameter

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use File::Copy;
use pf::condition_parser qw(parse_condition_string ast_to_object);
use pf::util::console;

my $COLORS = pf::util::console::colors();
my $old_ext = "old_pre_v10.1";
our $indent = "  ";

use pf::file_paths qw(
    $authentication_config_file
);

my %new_fields = (
    status => 'enabled',
);

sub upgrade_rule {
    my ($name) = @_;
    if (!-e $name) {
        return ( { file => $name, message => "file '$name' does not exists" }, undef );
    }

    my $cs = pf::IniFiles->new( -file => $name, -allowempty => 1, );
    if (!defined $cs) {
        return (
            {
                file    => $name,
                message => join( " ", @Config::IniFiles::errors )
            },
            undef
        );
    }

    my $changed = 0;
    my @warnings;

    for my $s (grep {/ rule /} $cs->Sections) {
        while (my ($k, $v) = each %new_fields) {
            if ($cs->exists($s, $k)) {
                push @warnings, { message => "$k already exists in $s", name => $name };
                next;
            }
            $changed |= 1;
            $cs->newval($s, $k, $v);
        }
    }

    if (!$changed) {
        return (undef, [{ message => 'No rules changed', name => $name }]);
    }

    copy($name, "$name.$old_ext");
    $cs->WriteConfig($name);
    return (undef, \@warnings);
}

sub make_error {
    my ($ctx, $message, @args) = @_;
    return { file => $ctx->{file}, message => $message, @args };
}

my @files = (
    $authentication_config_file
);

if (@ARGV) {
    @files = @ARGV;
}

sub display_error {
    my ($err) = @_;
    print $COLORS->{error}, $indent, $err->{message}, $COLORS->{reset}, "\n";
}

sub display_warning {
    my ($err) = @_;
    print $indent, $indent, $COLORS->{warning}, $err->{message}, $COLORS->{reset}, "\n";
}

for my $file (@files) {
    print "Upgrading $file to the new format\n";
    my ($err, $warnings) = upgrade_rule($file);
    if ($err) {
        display_error($err);
        print $indent, "Skipping\n";
    } else {
        print "${indent}Old config is located $file.$old_ext\n";
        if ($warnings && @$warnings) {
            for my $w (@$warnings) {
                display_warning($w);
            }
        }
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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
