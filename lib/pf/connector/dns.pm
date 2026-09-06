package pf::connector::dns;

=head1 NAME

pf::connector::dns - DNS servers behind a connector

=head1 DESCRIPTION

A connector can list the DNS servers of its site and the domains each of them
is authoritative for. PacketFence forwards the queries for those domains to
the server through the connector tunnel (pfdns-connector), which is also how
hostnames under those domains are routed to the connector.

The list lives in the connector's section of connectors.conf as one line per
server:

  dns_servers=<<EOT
  10.5.1.53 port=53 tunnel_port=30001 domains=inverse.local,corp.local
  EOT

C<tunnel_port> is the pfconnector server port forwarded to the DNS server
(30000-30999); it is allocated automatically when left empty. Structured
form, as the API and the admin form see it:

  { ip => '10.5.1.53', port => 53, tunnel_port => 30001,
    domains => ['inverse.local', 'corp.local'] }

This replaces the former dns_connectors.conf (one entry per DNS server, with a
hand-picked tunnel port) and domains_connectors.conf (domain -> connector):
listing a domain under a connector's DNS server is the mapping.

=cut

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(
    parse_dns_server_line format_dns_server
    expand_dns_servers flatten_dns_servers
    dns_server_id
    $TUNNEL_PORT_MIN $TUNNEL_PORT_MAX
);

our $TUNNEL_PORT_MIN = 30000;
our $TUNNEL_PORT_MAX = 30999;
our $DEFAULT_PORT    = 53;

=head2 parse_dns_server_line

"10.5.1.53 port=53 tunnel_port=30001 domains=a.local,b.local" -> hash, or
undef when the line cannot be parsed.

=cut

sub parse_dns_server_line {
    my ($line) = @_;
    return undef unless defined $line;
    my ($ip, @words) = split(/\s+/, _trim($line));
    return undef unless defined $ip && $ip =~ /^\d{1,3}(?:\.\d{1,3}){3}$/;
    my $s = { ip => $ip, port => $DEFAULT_PORT, tunnel_port => '', domains => [] };
    for my $word (@words) {
        my ($k, $v) = $word =~ /^([a-z_]+)=(.*)$/ or return undef;
        if ($k eq 'port') {
            $s->{port} = $v;
        } elsif ($k eq 'tunnel_port') {
            $s->{tunnel_port} = $v;
        } elsif ($k eq 'domains') {
            $s->{domains} = [ grep { length } split(/,/, $v) ];
        } else {
            return undef;
        }
    }
    return $s;
}

=head2 format_dns_server

Inverse of parse_dns_server_line.

=cut

sub format_dns_server {
    my ($s) = @_;
    my @words = ($s->{ip} // '');
    my $port = $s->{port};
    push @words, "port=$port" if defined $port && length $port;
    my $tp = $s->{tunnel_port};
    push @words, "tunnel_port=$tp" if defined $tp && length $tp;
    my @domains = grep { defined && length } map { _trim($_) } _list($s->{domains});
    push @words, "domains=" . join(',', @domains) if @domains;
    return join(' ', @words);
}

=head2 dns_server_id

The identifier of a server entry in the derived config::DnsConnectors
namespace: "<connector>:<ip>:<port>".

=cut

sub dns_server_id {
    my ($connector_id, $s) = @_;
    return join(':', $connector_id, $s->{ip} // '', ($s->{port} // $DEFAULT_PORT));
}

=head2 expand_dns_servers

Turn the dns_servers line list of a connector section into a list of hashes,
in place. Unparseable lines are dropped.

=cut

sub expand_dns_servers {
    my ($cfg) = @_;
    $cfg->{dns_servers} = [ grep { defined } map { ref($_) eq 'HASH' ? $_ : parse_dns_server_line($_) } _list($cfg->{dns_servers}) ];
    return $cfg;
}

=head2 flatten_dns_servers

Turn the structured list back into lines, in place. An empty list becomes
undef so the key is removed from the section.

=cut

sub flatten_dns_servers {
    my ($cfg) = @_;
    return $cfg unless exists $cfg->{dns_servers};
    my @lines = grep { length } map { ref($_) eq 'HASH' ? format_dns_server($_) : _trim($_) } _list($cfg->{dns_servers});
    $cfg->{dns_servers} = @lines ? \@lines : undef;
    return $cfg;
}

sub _list {
    my ($val) = @_;
    return () unless defined $val;
    return ref($val) eq 'ARRAY' ? @$val : grep { length _trim($_) } split(/\n/, $val);
}

sub _trim {
    my ($s) = @_;
    return '' unless defined $s;
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
