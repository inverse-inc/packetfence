package pf::services::manager::pfdns;

=head1 NAME

pf::services::manager::pfdns

=cut

=head1 DESCRIPTION

pf::services::manager::pfdns

=cut

use strict;
use warnings;
use Moo;
use Template;
use NetAddr::IP;

use pf::cluster;
use pf::config qw(
    %Config
    %ConfigNetworks
);

use pf::file_paths qw(
    $conf_dir
    $install_dir
    $var_dir
    $generated_conf_dir
);

use pf::util;
use pf::util::dns;
use pf::log;
use File::Slurp qw(write_file);

extends 'pf::services::manager';

has '+name' => ( default => sub { 'pfdns' } );

our $RESOLV_CONF = '/etc/resolv.conf';

tie our %domain_dns_servers, 'pfconfig::cached_hash', 'resource::domain_dns_servers';

=head2 generateConfig

Generate the configuration file

=cut

sub generateConfig {
    my ($self,$quick) = @_;
    my $tt = Template->new(ABSOLUTE => 1);
    my %tags;

    foreach my $key ( keys %domain_dns_servers ) {
        my $dns = join ' ',@{$domain_dns_servers{$key}};
        $tags{'domain'} .= <<"EOT";
    forward $key. $dns
EOT
    }

    foreach my $network ( keys %ConfigNetworks ) {
        # We skip non-inline networks/interfaces
        next if ( !pf::config::is_network_type_inline($network) );
        my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
        my $cidr = $net_addr->cidr();
        my $dns =  join ' ',split(',',$ConfigNetworks{$network}{'dns'});
        $tags{'inline'} .= <<"EOT";
    forward . $dns {
        network_source $cidr
    }
EOT
    }

    my $content = '';
    $tt->process("$conf_dir/pfdns.conf", \%tags, \$content) or die $tt->error();
    # The forward plugin refuses to start when pointed to a resolv.conf without a nameserver
    unless (@{ pf::util::dns::get_resolv_dns_servers($RESOLV_CONF) }) {
        get_logger->warn("No nameserver found in $RESOLV_CONF, pfdns will not forward the queries it doesn't handle. Restart pfdns once a nameserver is configured");
        $content = remove_resolv_conf_forwards($content);
    }
    write_file("$generated_conf_dir/pfdns.conf", $content);
}

=head2 remove_resolv_conf_forwards

Remove the forward directives (and their option block) that use the system resolv.conf

=cut

sub remove_resolv_conf_forwards {
    my ($content) = @_;
    $content =~ s/^[ \t]*forward[ \t]+\.[ \t]+\Q$RESOLV_CONF\E(?:[ \t]*\{[^}]*\})?[ \t]*\n//mg;
    return $content;
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
