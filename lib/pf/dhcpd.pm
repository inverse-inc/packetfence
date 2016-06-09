package pf::dhcpd;

=head1 NAME

pf::dhcpd - FreeRADIUS dhcpd configuration helper

=cut

=head1 DESCRIPTION

pf::dhcpd helps with some configuration aspects of FreeRADIUS dhcpd

=cut

use strict;
use warnings;

use Carp;
use pf::log;
use Readonly;
use NetAddr::IP;
use IO::Socket::INET;
use Net::DHCP::Packet;
use Net::DHCP::Constants;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        freeradius_populate_dhcpd_config
        freeradius_update_dhcpd_lease
        freeradius_delete_dhcpd_lease
        ping_dhcpd
    );
}

use pf::config qw (%ConfigNetworks);
use pf::config::cached;
use pf::db;
use pf::cluster qw(@cluster_servers);

# The next two variables and the _prepare sub are required for database handling magic (see pf::db)
our $dhcpd_db_prepared = 0;
# in this hash reference we hold the database statements. We pass it to the query handler and he will repopulate
# the hash if required
our $dhcpd_statements = {};

use constant DHCPD => 'dhcpd';

=head1 SUBROUTINES

=over

=item dhcpd_db_prepare

Prepares all the SQL statements related to this module

=cut

sub dhcpd_db_prepare {
    my $logger = get_logger();
    $logger->debug("Preparing pf::freeradius dhcpd database queries");
    my $dbh = get_db_handle();
    if($dbh) {

        $dhcpd_statements->{'freeradius_insert_dhcpd'} = $dbh->prepare(qq[
            INSERT INTO radippool (
                pool_name, framedipaddress
            ) VALUES (
                ?, ?
            ) ON DUPLICATE KEY UPDATE id=id
        ]);

        $dhcpd_statements->{'freeradius_insert_dhcpd_lease'} = $dbh->prepare(qq[
            UPDATE radippool
                SET lease_time = ?
            WHERE callingstationid = ?
        ]);

        $dhcpd_statements->{'freeradius_delete_dhcpd_lease'} = $dbh->prepare(qq[
            UPDATE radippool
                SET lease_time = ''
            WHERE callingstationid = ?
        ]);

        $dhcpd_statements->{'freeradius_insert_dhcpd_pool'} = $dbh->prepare(qq[
            INSERT INTO dhcpd (
                ip, interface, idx
            ) VALUES (
                ?, ?, ?
            )
        ]);

        $dhcpd_statements->{'freeradius_delete_dhcpd_pool'} = $dbh->prepare(qq[
            TRUNCATE dhcpd 
        ]);

        $dhcpd_db_prepared = 1;
    }
}


=item _insert_dhcpd

Add a new NAS (FreeRADIUS client) record

=cut

sub _insert_dhcpd {
    my ($pool_name, $framedipaddress) = @_;
    my $logger = get_logger();

    db_query_execute(
        DHCPD, $dhcpd_statements, 'freeradius_insert_dhcpd', $pool_name, $framedipaddress
    ) || return 0;
    return 1;
}

=item freeradius_populate_dhcpd_config

Populates the radippool table with ip.

=cut

sub freeradius_populate_dhcpd_config {
    my $logger = get_logger();
    return unless db_ping;

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};
        if ( $net{'dhcpd'} eq 'enabled' ) {
            my $current_network = NetAddr::IP->new( $network, $net{'netmask'} );
            my $network = $current_network->network();
            my $lower = NetAddr::IP->new( $net{'dhcp_start'}, $net{'netmask'});
            my $upper = NetAddr::IP->new( $net{'dhcp_end'}, $net{'netmask'});
            while ($current_network <= $upper) {
                if ($current_network < $lower ) {
                    $current_network ++;
                } else {
                    _insert_dhcpd($network,$current_network->addr());
                    $current_network ++;
                }
            }
        }
    }
}

=item freeradius_update_dhcpd_lease

Update dhcpd lease in radippool table

=cut

sub freeradius_update_dhcpd_lease {
    my ( $mac , $lease_time) = @_;

    return unless db_ping;
    db_query_execute(
        DHCPD, $dhcpd_statements, 'freeradius_insert_dhcpd_lease', $lease_time, $mac
    ) || return 0;
    return 1;
}


=item freeradius_delete_dhcpd_leas

Delete dhcp lease in radippool table
 
=cut

sub freeradius_delete_dhcpd_lease {
    my ( $mac) = @_;

    return unless db_ping;
    db_query_execute(
        DHCPD, $dhcpd_statements, 'freeradius_delete_dhcpd_lease', $mac
    ) || return 0;
    return 1;
}

=item ping_dhcpd

ping each dhcpd server interface to see if they are alive

=cut

sub ping_dhcpd {
    my $logger = get_logger();
    my $answer;
    my %index;
    foreach my $host (@cluster_servers) {
        for my $interface (keys $host) {
            next if ( ( $interface !~ /^interface (.*)/) || ($host->{$interface}->{type} ne 'internal') );
            my $eth = $1;
            my $dhcpreq = new Net::DHCP::Packet(
                Op => BOOTREQUEST(),
                Htype => HTYPE_ETHER(),
                Hops => '0',
                Xid => '01101',
                Flags => '0',
                Ciaddr => '0.0.0.0',
                Yiaddr => '0.0.0.0',
                Siaddr => '0.0.0.0',
                Giaddr => '0.0.0.0',
                Chaddr => "001122334455",
                DHO_DHCP_MESSAGE_TYPE() => DHCPLEASEQUERY()
            );
            my $fromaddr;
            undef $@;
            eval {
                local $SIG{ALRM} = sub { die 'Timed Out'; };
                alarm 2;
                my $sock_out = IO::Socket::INET->new(Type => SOCK_DGRAM, Reuse => 1, LocalPort => 68, Proto => 'udp',PeerAddr => $host->{$interface}->{ip}.':67');
                # Send the packet to the network
                my $data;
                $sock_out->send($dhcpreq->serialize());
                $fromaddr = $sock_out->recv($data, 4096);
                alarm 0;
            };
            alarm 0;
            next if ( $@ && $@ =~ /Timed Out/ );
            next if (!defined($fromaddr));
            my ($port,$addr) = unpack_sockaddr_in($fromaddr);
            my $ipaddr = inet_ntoa($addr);
            $index{$eth} = ( defined($index{$eth}) ? $index{$eth} + 1 : 0);
            my %info = (
                'interface' => $eth,
                'index' => $index{$eth},
            );
            $i++;
            $answer->{$host->{$interface}->{ip}} = \%info;
        }
    }
    db_query_execute(
            DHCPD, $dhcpd_statements, 'freeradius_delete_dhcpd_pool');
    if (defined($answer)) {
        for my $server (keys $answer) {
            db_query_execute(
                DHCPD, $dhcpd_statements, 'freeradius_insert_dhcpd_pool', $server, $answer->{$server}{'interface'}, $answer->{$server}{'index'}
            );
        }
    }
}


=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
