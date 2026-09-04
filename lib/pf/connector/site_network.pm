package pf::connector::site_network;

=head1 NAME

pf::connector::site_network - on-disk <-> structured representation of a
connector's site networking (VLAN interfaces and static routes)

=head1 DESCRIPTION

A connector can terminate VLANs on the pfconnector-remote host. In
connectors.conf each VLAN interface and each static route is stored as one
human readable line, in a multi-line value:

  interfaces=<<EOT
  eth0.100 10.10.100.1/24
  eth0.101 10.10.101.1/24
  EOT
  routes=<<EOT
  10.20.0.0/16 via 10.10.100.254 dev eth0.100
  192.168.50.0/24 dev eth0.101
  EOT

The API, the admin form and pfconfig work with the structured form:

  interfaces => [ { parent => 'eth0', vlan => 100, cidr => '10.10.100.1/24' }, ... ]
  routes     => [ { destination => '10.20.0.0/16', gateway => '10.10.100.254', interface => 'eth0.100' }, ... ]

The VLAN interface name is always C<< <parent>.<vlan> >>, which is what the
connector creates on the host. Interface names are limited to 15 characters
by the kernel (IFNAMSIZ), so the parent name is at most 10 characters.

=cut

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(
    parse_interface_line format_interface interface_name
    parse_route_line format_route
    expand_site_network flatten_site_network
    $IFNAMSIZ
);

# Linux IFNAMSIZ minus the trailing NUL
our $IFNAMSIZ = 15;

=head2 interface_name

Name of the VLAN interface created for a structured interface entry.

=cut

sub interface_name {
    my ($if) = @_;
    return "$if->{parent}.$if->{vlan}";
}

=head2 parse_interface_line

"eth0.100 10.10.100.1/24" -> { parent => 'eth0', vlan => 100, cidr => '10.10.100.1/24' }

Returns undef when the line cannot be parsed.

=cut

sub parse_interface_line {
    my ($line) = @_;
    return undef unless defined $line;
    my ($name, $cidr, @extra) = split(/\s+/, _trim($line));
    return undef unless defined $name && defined $cidr;
    my ($parent, $vlan) = $name =~ /^(.+)\.(\d+)$/;
    return undef unless defined $parent;
    return { parent => $parent, vlan => int($vlan), cidr => $cidr };
}

=head2 format_interface

Inverse of parse_interface_line.

=cut

sub format_interface {
    my ($if) = @_;
    return interface_name($if) . " " . ($if->{cidr} // '');
}

=head2 parse_route_line

"10.20.0.0/16 via 10.10.100.254 dev eth0.100" ->
  { destination => '10.20.0.0/16', gateway => '10.10.100.254', interface => 'eth0.100' }

Both "via" and "dev" are optional. Returns undef when the line cannot be parsed.

=cut

sub parse_route_line {
    my ($line) = @_;
    return undef unless defined $line;
    my ($destination, @words) = split(/\s+/, _trim($line));
    return undef unless defined $destination && length $destination;
    my $route = { destination => $destination, gateway => '', interface => '' };
    while (@words) {
        my $kw = shift @words;
        my $val = shift @words;
        return undef unless defined $val;
        if ($kw eq 'via') {
            $route->{gateway} = $val;
        } elsif ($kw eq 'dev') {
            $route->{interface} = $val;
        } else {
            return undef;
        }
    }
    return $route;
}

=head2 format_route

Inverse of parse_route_line.

=cut

sub format_route {
    my ($route) = @_;
    my @words = ($route->{destination} // '');
    push @words, 'via', $route->{gateway} if defined $route->{gateway} && length $route->{gateway};
    push @words, 'dev', $route->{interface} if defined $route->{interface} && length $route->{interface};
    return join(' ', @words);
}

=head2 expand_site_network

Turn the on-disk line lists of a connector hash into structured lists, in
place. Accepts either an array of lines or a newline separated string.
Unparseable lines are dropped.

=cut

sub expand_site_network {
    my ($cfg) = @_;
    $cfg->{interfaces} = [ grep { defined } map { parse_interface_line($_) } _lines($cfg->{interfaces}) ];
    $cfg->{routes}     = [ grep { defined } map { parse_route_line($_) }     _lines($cfg->{routes}) ];
    return $cfg;
}

=head2 flatten_site_network

Turn structured lists back into line lists, in place. Entries that are
already strings are kept as is. Empty lists become undef so the key is
removed from the section.

=cut

sub flatten_site_network {
    my ($cfg) = @_;
    for my $spec ([interfaces => \&format_interface], [routes => \&format_route]) {
        my ($key, $format) = @$spec;
        next unless exists $cfg->{$key};
        my @lines = map { ref($_) eq 'HASH' ? $format->($_) : $_ } _lines($cfg->{$key});
        $cfg->{$key} = @lines ? \@lines : undef;
    }
    return $cfg;
}

sub _lines {
    my ($val) = @_;
    return () unless defined $val;
    my @items = ref($val) eq 'ARRAY' ? @$val : split(/\n/, $val);
    return grep { ref($_) || (defined $_ && length _trim($_)) } @items;
}

sub _trim {
    my ($s) = @_;
    $s =~ s/^\s+|\s+$//g;
    return $s;
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
