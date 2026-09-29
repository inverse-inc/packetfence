package pf::util::radius_dictionary_local;

=head1 NAME

pf::util::radius_dictionary_local - merge the local RADIUS dictionary

=head1 DESCRIPTION

pf::util::radius_dictionary is generated from the FreeRADIUS dictionaries
shipped with PacketFence. Attributes an administrator adds for a device
(for instance a custom vendor-specific attribute used in a switch template)
live in conf/radiusd/dictionary.local, which FreeRADIUS includes through
raddb/dictionary. This module parses that file, in the FreeRADIUS dictionary
format, and merges it into the Net::Radius::Dictionary object, so the same
attributes can be sent in CoA and Disconnect requests and used in templates.

A service must be restarted to pick up a change of the file.

=cut

use strict;
use warnings;
use File::Basename qw(dirname);
use File::Spec;

use pf::file_paths qw($conf_dir);

our $LOCAL_DICTIONARY_FILE = "$conf_dir/radiusd/dictionary.local";

=head2 merge

merge($dictionary, $file) - merge $file (default: conf/radiusd/dictionary.local)
into $dictionary. A missing file is not an error. Returns the list of warnings
for the lines that could not be used.

=cut

sub merge {
    my ($dict, $file) = @_;
    $file //= $LOCAL_DICTIONARY_FILE;
    my @warnings;
    return @warnings unless -e $file;
    _read($dict, $file, \@warnings, {});
    return @warnings;
}

sub _number {
    my ($n) = @_;
    return undef unless defined $n;
    return hex($1) if $n =~ /^0x([0-9a-f]+)$/i;
    return $n + 0 if $n =~ /^\d+$/;
    return undef;
}

sub _read {
    my ($dict, $file, $warnings, $seen) = @_;
    my $real = File::Spec->rel2abs($file);
    if ($seen->{$real}++) {
        push @$warnings, "$file: already included, skipped";
        return;
    }
    my $fh;
    unless (open($fh, '<', $file)) {
        push @$warnings, "$file: cannot open: $!";
        return;
    }
    my $vendor;    # set between BEGIN-VENDOR and END-VENDOR
    while (my $line = <$fh>) {
        $line =~ s/#.*//;
        my @f = split ' ', $line;
        next unless @f;
        my $keyword = uc($f[0]);
        my $where = "$file line $.";
        if ($keyword eq '$INCLUDE' || $keyword eq '$INCLUDE-') {
            my $inc = $f[1] // '';
            $inc = File::Spec->catfile(dirname($file), $inc) unless File::Spec->file_name_is_absolute($inc);
            if (!-e $inc) {
                push @$warnings, "$where: include $inc not found" if $keyword eq '$INCLUDE';
                next;
            }
            _read($dict, $inc, $warnings, $seen);
        }
        elsif ($keyword eq 'VENDOR') {
            my $id = _number($f[2]);
            if (!defined $f[1] || !defined $id) {
                push @$warnings, "$where: invalid VENDOR";
                next;
            }
            $dict->{vendors}{$f[1]} = $id;
        }
        elsif ($keyword eq 'BEGIN-VENDOR') {
            if (!defined $f[1] || !exists $dict->{vendors}{$f[1]}) {
                push @$warnings, "$where: unknown vendor " . ($f[1] // '');
                $vendor = undef;
                next;
            }
            $vendor = $f[1];
        }
        elsif ($keyword eq 'END-VENDOR') {
            $vendor = undef;
        }
        elsif ($keyword eq 'ATTRIBUTE') {
            my ($name, $number, $type, $extra) = @f[1 .. 4];
            my $num = _number($number);
            if (!defined $name || !defined $num || !defined $type) {
                push @$warnings, "$where: invalid ATTRIBUTE";
                next;
            }
            # old style: ATTRIBUTE name number type vendor
            my $attr_vendor = $vendor;
            $attr_vendor = $extra if !defined $attr_vendor && defined $extra && exists $dict->{vendors}{$extra};
            if (defined $attr_vendor) {
                my $id = $dict->{vendors}{$attr_vendor};
                $dict->{vsattr}{$id}{$name} = [ $num, $type ];
                $dict->{rvsattr}{$id}{$num} = [ $name, $type ];
                $dict->{avendors}{$name} = $attr_vendor;
            }
            else {
                $dict->{attr}{$name} = [ $num, $type ];
                $dict->{rattr}{$num} = [ $name, $type ];
            }
        }
        elsif ($keyword eq 'VALUE') {
            my ($attr, $value_name, $value) = @f[1 .. 3];
            my $v = _number($value);
            if (!defined $attr || !defined $value_name || !defined $v) {
                push @$warnings, "$where: invalid VALUE";
                next;
            }
            if (exists $dict->{attr}{$attr}) {
                my $num = $dict->{attr}{$attr}[0];
                $dict->{val}{$num}{$value_name} = $v;
                $dict->{rval}{$num}{$v} = $value_name;
            }
            elsif (exists $dict->{avendors}{$attr}) {
                my $id = $dict->{vendors}{ $dict->{avendors}{$attr} };
                my $num = $dict->{vsattr}{$id}{$attr}[0];
                $dict->{vsaval}{$id}{$num}{$value_name} = $v;
                $dict->{rvsaval}{$id}{$num}{$v} = $value_name;
            }
            else {
                push @$warnings, "$where: VALUE for unknown attribute $attr";
            }
        }
        else {
            push @$warnings, "$where: unsupported keyword $f[0], ignored";
        }
    }
    close($fh);
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
