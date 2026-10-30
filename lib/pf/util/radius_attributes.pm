package pf::util::radius_attributes;

=head1 NAME

pf::util::radius_attributes - RADIUS attributes written as text

=head1 DESCRIPTION

Parse the RADIUS attributes of the Role by RADIUS attributes mapping of the
switches, one "Attribute-Name = value" per line.

=cut

use strict;
use warnings;
use Exporter qw(import);
use Socket qw(inet_pton AF_INET AF_INET6);
use pf::util::radius_dictionary qw($RADIUS_DICTIONARY);

our @EXPORT_OK = qw(
    parse_radius_attribute_line
    radius_attribute_definition
    radius_attribute_entries
    radius_attribute_error
    radius_attribute_log_value
    radius_attribute_lines
    radius_attribute_line_errors
);

=head2 radius_attribute_lines

The lines of a text, without the empty lines and the comments (starting with #)

=cut

sub radius_attribute_lines {
    my ($text) = @_;
    return () if !defined $text;
    $text = join("\n", @$text) if ref($text) eq 'ARRAY';
    return grep {
        $_ !~ /
            ^\s*    # leading spaces
            (\#|$)  # a comment or an empty line
        /x
    } split /\r?\n/, $text;
}

=head2 parse_radius_attribute_line

Parse a "Attribute-Name = value" line, return the name and the value, or nothing
when the line has another format.

One pair of double quotes around the value is removed, as in the FreeRADIUS
files: 'Filter-Id = "staff"' is the value staff. The quotes inside the value
are kept.

=cut

sub parse_radius_attribute_line {
    my ($line) = @_;
    my ($name, $value) = $line =~ /
        ^\s*
        ([\w-]+)   # attribute name
        \s*=\s*
        (.*?)      # value, may contain =
        \s*$
    /x;
    return if !defined $name;
    $value =~ s/
        ^"(.*)"$   # one pair of double quotes around the value
    /$1/sx;
    return if $value eq '';
    return ($name, $value);
}

=head2 radius_attribute_definition

The definition of an attribute in the RADIUS dictionary: its name as written
in the dictionary, its type, the named values of the attribute (a hash of
name => number), its number and its vendor (undef for a standard attribute), or
nothing when the attribute is not in the dictionary. FreeRADIUS matches the
names without regard to case.

=cut

my %lc_names;

sub radius_attribute_definition {
    my ($name) = @_;
    return if !defined $name;
    my $dict = $RADIUS_DICTIONARY;
    if (!exists $dict->{attr}{$name} && !exists $dict->{avendors}{$name}) {
        if (!%lc_names) {
            %lc_names = map { lc($_) => $_ } keys %{$dict->{attr}}, keys %{$dict->{avendors}};
        }
        $name = $lc_names{lc($name)};
        return if !defined $name;
    }
    if (exists $dict->{attr}{$name}) {
        my ($number, $type) = @{$dict->{attr}{$name}};
        return ($name, $type, $dict->{val}{$number} // {}, $number, undef);
    }
    my $vendor_id = $dict->{vendors}{$dict->{avendors}{$name}};
    my $definition = defined $vendor_id ? $dict->{vsattr}{$vendor_id}{$name} : undef;
    return if !defined $definition;
    my ($number, $type) = @$definition;
    return ($name, $type, $dict->{vsaval}{$vendor_id}{$number} // {}, $number, $dict->{avendors}{$name});
}

# The largest value of the unsigned types, in decimal and in hexadecimal digits
my %UNSIGNED_MAX = (
    byte      => [ '255',                  2 ],
    short     => [ '65535',                4 ],
    integer   => [ '4294967295',           8 ],
    integer64 => [ '18446744073709551615', 16 ],
);

my @MONTHS = qw(jan feb mar apr may jun jul aug sep oct nov dec);

# Is $number (digits) at most $max (digits), compared as strings to not overflow
sub _not_above {
    my ($number, $max) = @_;
    $number =~ s/^0+(?=\d)//;
    return length($number) < length($max) || (length($number) == length($max) && $number le $max);
}

sub _valid_unsigned {
    my ($value, $type) = @_;
    my ($max, $hex_digits) = @{$UNSIGNED_MAX{$type}};
    # the largest value is all the hexadecimal digits at f
    return length($1) <= $hex_digits if $value =~ /
        ^0x0*
        ([0-9a-f]+)   # the hexadecimal digits without the leading zeros
        $
    /xi;
    return $value =~ /^\d+$/ && _not_above($value, $max);
}

sub _valid_signed {
    my ($value) = @_;
    return 0 if $value !~ /
        ^([-+]?)   # sign
        (\d+)$     # digits
    /x;
    return _not_above($2, $1 eq '-' ? '2147483648' : '2147483647');
}

sub _valid_ipv4 {
    my ($value) = @_;
    return $value =~ /
        ^\d{1,3}(\.\d{1,3}){3}$   # dotted quad, inet_pton also accepts other forms
    /x && defined inet_pton(AF_INET, $value);
}

sub _valid_ipv6 {
    my ($value) = @_;
    return defined inet_pton(AF_INET6, $value);
}

sub _valid_prefix {
    my ($value, $valid_ip, $max_length) = @_;
    return 0 if $value !~ m{
        ^(.+)          # address
        /(\d{1,3})$    # prefix length
    }x;
    return $valid_ip->($1) && $2 <= $max_length;
}

# The formats of FreeRADIUS: seconds since the epoch or "Jan 1 2027 08:00:00 UTC"
sub _valid_date {
    my ($value) = @_;
    return 1 if $value =~ /^\d+$/ && _not_above($value, '4294967295');
    my ($month, $day) = $value =~ /
        ^([a-z]{3})[a-z]*\.?    # month name
        \s+(\d{1,2}),?          # day
        \s+\d{4}                # year
        (?:\s+\d{1,2}:\d{2}(?::\d{2})?)?  # time
        (?:\s+[a-z]+)?$         # time zone
    /xi;
    return defined $month && (grep { $_ eq lc($month) } @MONTHS) && $day >= 1 && $day <= 31;
}

my %VALID_VALUE = (
    (map { my $type = $_; ($type => sub { _valid_unsigned($_[0], $type) }) } keys %UNSIGNED_MAX),
    signed     => \&_valid_signed,
    ipaddr     => \&_valid_ipv4,
    ipv6addr   => \&_valid_ipv6,
    ipv4prefix => sub { _valid_prefix($_[0], \&_valid_ipv4, 32) },
    ipv6prefix => sub { _valid_prefix($_[0], \&_valid_ipv6, 128) },
    date       => \&_valid_date,
    ether      => sub {
        $_[0] =~ /
            ^[0-9a-f]{1,2}
            ([:-])                     # separator, the same between all the bytes
            [0-9a-f]{1,2}
            (\1[0-9a-f]{1,2}){4}$
        /xi
    },
    ifid       => sub {
        $_[0] =~ /
            ^[0-9a-f]{1,4}(:[0-9a-f]{1,4}){3}$   # four groups of 16 bits
        /xi
    },
    # FreeRADIUS reads a value starting with 0x as hexadecimal
    octets     => sub {
        $_[0] !~ /^0x/i || $_[0] =~ /
            ^0x([0-9a-f]{2})*$   # whole bytes
        /xi
    },
);

=head2 radius_attribute_error

The reason why an attribute and its value can't be returned: the attribute is
not in the RADIUS dictionary, it is an internal attribute of FreeRADIUS, which is
never sent to the switch (a standard attribute with a number above 255, such as
Auth-Type or Cleartext-Password), or the value is not valid for the type of the
attribute. Nothing when they can be returned.

The values of the integer types can be a number or a value named in the
dictionary (Tunnel-Type = VLAN). The values of the types that are not checked
(string, abinary, ...) are always valid.

=cut

sub radius_attribute_error {
    my ($name, $value) = @_;
    my ($dict_name, $type, $named_values, $number, $vendor) = radius_attribute_definition($name);
    return "$name is not in the RADIUS dictionary" if !defined $dict_name;
    # The attributes on the wire have a number from 1 to 255
    return "$dict_name is an internal attribute of FreeRADIUS, it is not sent to the switch"
        if !defined $vendor && $number > 255;
    my $valid = $VALID_VALUE{$type};
    return if !defined $valid || $valid->($value);
    if (exists $UNSIGNED_MAX{$type}) {
        return if grep { lc($_) eq lc($value) } keys %$named_values;
        if (%$named_values) {
            my @names = sort keys %$named_values;
            splice(@names, 30, @names, '...') if @names > 30;
            return "'$value' is not a valid value of $dict_name, a number or one of " . join(', ', @names);
        }
    }
    return "'$value' is not a valid $type for $dict_name";
}

=head2 radius_attribute_log_value

The value of an attribute as it can be written in the logs: hidden for the
attributes that carry a secret (Tunnel-Password, MS-MPPE-Send-Key, ...)

=cut

sub radius_attribute_log_value {
    my ($name, $value) = @_;
    return $name =~ /
        password | secret | key | psk   # the names of the attributes that carry a secret
    /xi ? '********' : $value;
}

=head2 radius_attribute_entries

The lines of a text, parsed and checked: for each line, the line, the name and
the value of the attribute (undef when the line is not a "Attribute-Name = value"
line) and the reason why it can't be returned (undef when it can)

=cut

sub radius_attribute_entries {
    my ($text) = @_;
    return map {
        my ($name, $value) = parse_radius_attribute_line($_);
        +{
            line  => $_,
            name  => $name,
            value => $value,
            error => defined $name ? scalar(radius_attribute_error($name, $value)) : "the format is 'Attribute-Name = value'",
        }
    } radius_attribute_lines($text);
}

=head2 radius_attribute_line_errors

The errors of the lines of a text that are not a "Attribute-Name = value" line
with an attribute of the RADIUS dictionary and a valid value

=cut

sub radius_attribute_line_errors {
    my ($text) = @_;
    return map { "$_->{line}: $_->{error}" } grep { defined $_->{error} } radius_attribute_entries($text);
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
