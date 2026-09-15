package pf::connector::site_network;

=head1 NAME

pf::connector::site_network - on-disk <-> structured representation of a
connector's site networking (interfaces and static routes)

=head1 DESCRIPTION

A connector can terminate VLANs on the pfconnector-remote host and address
its secondary network interfaces. In connectors.conf each interface and each
static route is stored as one human readable line, in a multi-line value:

  interfaces=<<EOT
  eth0.100 10.10.100.1/24 dhcp start=10.10.100.10 end=10.10.100.250 lease=300 max_lease=600 dns=8.8.8.8,8.8.4.4 gateway=10.10.100.254 domain=site.example
  eth0.101 10.10.101.1/24
  ens192 192.168.50.1/24 dhcp start=192.168.50.10 end=192.168.50.250
  EOT
  routes=<<EOT
  10.20.0.0/16 via 10.10.100.254 dev eth0.100
  192.168.50.0/24 dev eth0.101
  EOT

The API, the admin form and pfconfig work with the structured form:

  interfaces => [ {
      parent => 'eth0', vlan => 100, cidr => '10.10.100.1/24',
      dhcp => 'enabled', dhcp_start => '10.10.100.10', dhcp_end => '10.10.100.250',
      dhcp_default_lease_time => 300, dhcp_max_lease_time => 600,
      dns => '8.8.8.8,8.8.4.4', gateway => '10.10.100.254', domain_name => 'site.example',
  }, {
      parent => 'ens192', vlan => undef, cidr => '192.168.50.1/24', ...
  }, ... ]
  routes     => [ { destination => '10.20.0.0/16', gateway => '10.10.100.254', interface => 'eth0.100' }, ... ]

Words after the address are flags and the DHCP scope: the C<dhcp> flag
enables the DHCP relay on the interface (dhcp => enabled / disabled), the
C<dns> flag enables the captive DNS responder that answers every query with
the interface address (dns_server => enabled / disabled), and the
C<key=value> words describe the scope pfdhcp serves (DHCP-over-HTTPS):
C<start>/C<end> (range), C<lease>/C<max_lease> (seconds), C<dns>
(comma separated DNS servers handed to clients), C<gateway> (the interface
address when absent), C<domain>.

A name of the form C<< <parent>.<vlan> >> is an 802.1Q VLAN interface the
connector creates on the host on top of C<parent>. A name without a VLAN
suffix (C<vlan> undef in the structured form) is an existing interface of the
host, e.g. a second NIC, that the connector only addresses: it never creates
or deletes it, and the connector refuses to touch the host's main interface
(the one holding the default route, which carries the tunnel). Interface
names are limited to 15 characters by the kernel (IFNAMSIZ), so the parent of
a VLAN interface is at most 10 characters.

=cut

use strict;
use warnings;

use Exporter qw(import);
use pf::util qw(isenabled);
our @EXPORT_OK = qw(
    parse_interface_line format_interface interface_name is_vlan_interface
    parse_route_line format_route
    expand_site_network flatten_site_network
    $IFNAMSIZ
);

# Linux IFNAMSIZ minus the trailing NUL
our $IFNAMSIZ = 15;

=head2 interface_name

Kernel name of the interface a structured entry describes: C<parent.vlan>
for a VLAN interface, the parent itself when C<vlan> is empty.

=cut

sub interface_name {
    my ($if) = @_;
    my $vlan = $if->{vlan};
    return $if->{parent} unless defined $vlan && length $vlan && $vlan != 0;
    return "$if->{parent}.$vlan";
}

=head2 is_vlan_interface

True when a structured entry is a VLAN interface (has a VLAN id).

=cut

sub is_vlan_interface {
    my ($if) = @_;
    return interface_name($if) ne ($if->{parent} // '');
}

=head2 parse_interface_line

"eth0.100 10.10.100.1/24 dhcp start=... end=..." -> structured hash (see
DESCRIPTION). A name without a ".<vlan>" suffix is the interface itself
(vlan => undef). Returns undef when the line cannot be parsed.

=cut

# bare storage word => structured key ("enabled"/"disabled")
our %INTERFACE_FLAGS = (dhcp => 'dhcp', dns => 'dns_server');
# storage word => structured key, in storage order
our @INTERFACE_KEYS = (
    [start     => 'dhcp_start'],
    [end       => 'dhcp_end'],
    [lease     => 'dhcp_default_lease_time'],
    [max_lease => 'dhcp_max_lease_time'],
    [dns       => 'dns'],
    [gateway   => 'gateway'],
    [domain    => 'domain_name'],
);
my %INTERFACE_KEY_OF = map { $_->[0] => $_->[1] } @INTERFACE_KEYS;

sub parse_interface_line {
    my ($line) = @_;
    return undef unless defined $line;
    my ($name, $cidr, @words) = split(/\s+/, _trim($line));
    return undef unless defined $name && defined $cidr;
    my ($parent, $vlan) = $name =~ /^(.+)\.(\d+)$/;
    if (!defined $parent) {
        # no VLAN suffix: the interface itself; a dot in the name is garbage
        return undef if $name =~ /[^A-Za-z0-9_-]/;
        ($parent, $vlan) = ($name, undef);
    }
    my $if = {
        parent => $parent,
        vlan   => defined $vlan ? int($vlan) : undef,
        cidr   => $cidr,
        (map { $_ => 'disabled' } values %INTERFACE_FLAGS),
        (map { $_->[1] => '' } @INTERFACE_KEYS),
    };
    for my $word (@words) {
        if (my ($k, $v) = $word =~ /^([a-z_]+)=(.*)$/) {
            my $key = $INTERFACE_KEY_OF{$k} or return undef;
            $if->{$key} = $v;
        } else {
            my $key = $INTERFACE_FLAGS{$word} or return undef;
            $if->{$key} = 'enabled';
        }
    }
    return $if;
}

=head2 format_interface

Inverse of parse_interface_line. The DHCP scope words are only written when
the flag is enabled.

=cut

sub format_interface {
    my ($if) = @_;
    my @words = (interface_name($if), $if->{cidr} // '');
    for my $flag (sort keys %INTERFACE_FLAGS) {
        push @words, $flag if isenabled($if->{ $INTERFACE_FLAGS{$flag} });
    }
    if (isenabled($if->{dhcp})) {
        for my $spec (@INTERFACE_KEYS) {
            my ($word, $key) = @$spec;
            my $v = $if->{$key};
            next unless defined $v && length $v;
            $v =~ s/\s+//g;
            push @words, "$word=$v";
        }
    }
    return join(' ', @words);
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
