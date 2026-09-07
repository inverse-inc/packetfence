#!/usr/bin/perl

=head1 NAME

to-16.0-connectors-dns-servers.pl

=head1 DESCRIPTION

Fold dns_connectors.conf (DNS servers behind the connectors, with a hand-picked
tunnel port and the domains they serve) and domains_connectors.conf (domain ->
connector) into the connectors' own dns_servers list in connectors.conf (see
pf::connector::dns). Each DNS server goes under the connector its first domain
was mapped to. Domain mappings without a DNS server had no effect and are
dropped with a notice. The two old files are renamed with a .migrated suffix.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($connectors_config_file $dns_connectors_config_file $domains_connectors_config_file);
use pf::connector::dns qw(parse_dns_server_line format_dns_server);
use pf::util;

run_as_pf();

my $dns_file     = $dns_connectors_config_file;
my $domains_file = $domains_connectors_config_file;
unless (-f $dns_file || -f $domains_file) {
    print "No dns_connectors.conf or domains_connectors.conf to migrate\n";
    exit 0;
}

my $connectors = pf::IniFiles->new(-file => $connectors_config_file, -allowempty => 1)
  or die "Unable to read $connectors_config_file\n";

my %domain_to_connector;
if (-f $domains_file) {
    my $domains = pf::IniFiles->new(-file => $domains_file, -allowempty => 1);
    for my $domain ($domains ? $domains->Sections : ()) {
        my $connector = $domains->val($domain, 'connector');
        $domain_to_connector{$domain} = $connector if defined $connector && length $connector;
    }
}

my (%servers_of, %domains_used);
if (-f $dns_file) {
    my $dns = pf::IniFiles->new(-file => $dns_file, -allowempty => 1);
    for my $id ($dns ? $dns->Sections : ()) {
        my @domains = grep { length } map { s/^\s+|\s+$//gr } split(/,|\n/, $dns->val($id, 'domains') // '');
        my ($connector) = grep { defined } map { $domain_to_connector{$_} } @domains;
        if (!defined $connector) {
            print "Skipping DNS server '$id': none of its domains (@domains) is mapped to a connector\n";
            next;
        }
        unless ($connectors->SectionExists($connector)) {
            print "Skipping DNS server '$id': connector '$connector' does not exist\n";
            next;
        }
        push @{ $servers_of{$connector} }, format_dns_server({
            ip          => $dns->val($id, 'ip'),
            port        => $dns->val($id, 'port') // 53,
            tunnel_port => $dns->val($id, 'pfconnector_port') // '',
            domains     => \@domains,
        });
        $domains_used{$_} = 1 for @domains;
    }
}

for my $connector (sort keys %servers_of) {
    my @existing = grep { length } map { s/^\s+|\s+$//gr } split(/\n/, $connectors->val($connector, 'dns_servers') // '');
    # Idempotent: a server already on the connector (same ip:port, e.g. from an
    # earlier run whose rename below failed) is not added twice.
    my %present = map { my $s = parse_dns_server_line($_); $s ? ( "$s->{ip}:$s->{port}" => 1 ) : () } @existing;
    my @new = grep { my $s = parse_dns_server_line($_); !( $s && $present{"$s->{ip}:$s->{port}"} ) } @{ $servers_of{$connector} };
    $servers_of{$connector} = \@new;
    next unless @new;
    my @lines = (@existing, @new);
    if ($connectors->exists($connector, 'dns_servers')) {
        $connectors->setval($connector, 'dns_servers', @lines);
    } else {
        $connectors->newval($connector, 'dns_servers', @lines);
    }
    print "Connector '$connector': " . scalar(@{ $servers_of{$connector} }) . " DNS server(s) moved to connectors.conf\n";
}
$connectors->RewriteConfig() if %servers_of;

for my $domain (sort keys %domain_to_connector) {
    next if $domains_used{$domain};
    print "Dropping domain mapping '$domain' -> '$domain_to_connector{$domain}': no DNS server served it\n";
}

my $failed = 0;
for my $f ($dns_file, $domains_file) {
    next unless -f $f;
    if (rename $f, "$f.migrated") {
        print "Renamed $f to $f.migrated\n";
    } else {
        warn "Unable to rename $f: $!\n";
        $failed = 1;
    }
}
exit $failed;
