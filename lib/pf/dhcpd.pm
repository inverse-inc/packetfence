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
use pf::nodecategory qw(nodecategory_view_all);
use pf::util;
use Readonly;
use NetAddr::IP;
use IO::Socket::INET;
use Net::DHCP::Packet;
use Net::DHCP::Constants;
use IPC::Cmd qw[can_run run];
use POSIX qw(ceil);

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        freeradius_populate_dhcpd_config
        freeradius_update_dhcpd_lease
        freeradius_delete_dhcpd_lease
        ping_dhcpd
        dhcprole
    );
}

use pf::config qw (
    %ConfigNetworks
    %Config
    @listen_ints
);

use pf::config::cached;
use pf::db;
use pf::cluster qw(@cluster_servers);
use pf::radius::constants;
use pf::node qw(node_attributes);
use pf::file_paths qw($install_dir);

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

        $dhcpd_statements->{'freeradius_replace_password'} = $dbh->prepare(qq[
            REPLACE INTO dhcpd (
                ip, interface, idx
            ) VALUES (
                ?, ?, ?
            )
        ]);

        $dhcpd_statements->{'freeradius_select_dhcpd_pool'} = $dbh->prepare(qq[
            SELECT * FROM radippool
            WHERE pool_name = ?
        ]);

        $dhcpd_db_prepared = 1;
    }
}


=item _insert_dhcpd

Add a new IP in pool (FreeRADIUS dhcpd pool) record

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

    my $full_path = can_run('ip');
    my $fh;
    if (-f "$install_dir/var/routes.bak") {
        open ($fh, "$install_dir/var/routes.bak");
        while (my $row = <$fh>) {
            chomp $row;
            my $cmd = untaint_chain($row);
            my @out = pf_run($cmd);
        }
       close $fh;
    }
    open ($fh, "+>$install_dir/var/routes.bak");

    foreach my $interface ( @listen_ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        my $current_interface = NetAddr::IP->new( $cfg->{'ip'}, $cfg->{'mask'} );

        foreach my $network ( keys %ConfigNetworks ) {
            # shorter, more convenient local accessor
            my %net = %{$ConfigNetworks{$network}};
            my $current_network = NetAddr::IP->new( $network, $net{'netmask'} );
            my $ip = NetAddr::IP::Lite->new(clean_ip($net{'gateway'}));
            if (defined($net{'next_hop'})) {
                $ip = NetAddr::IP::Lite->new(clean_ip($net{'next_hop'}));
            }
            if ($current_interface->contains($ip)) {
                if ( $net{'dhcpd'} eq 'enabled' ) {
                    if (isenabled($net{'split_network'})) {
                        my @categories = nodecategory_view_all();
                        my $count = @categories;
                        my $len = $current_network->masklen;
                        my $cidr = (ceil(log($count)/log(2)) + $len);
                        if ($cidr > 30) {
                            $logger->error("Can't split network");
                            return;
                        }
                        my @sub_net = $current_network->split($cidr);
                        foreach my $net (@sub_net) {
                            my $role = pop @categories;
                            next unless $role->{'name'};
                            my $pool = $role->{'name'}.$interface;
                            my $pf_ip = $net + 1;
                            my $cmd = "sudo $full_path addr del ".$pf_ip->addr."/32 dev $interface";
                            $cmd = untaint_chain($cmd);
                            print $fh $cmd."\n";
                            my @out = pf_run($cmd);
                            $cmd = "sudo $full_path addr add ".$pf_ip->addr."/32 dev $interface";
                            @out = pf_run($cmd);
                            my $first = $net + 2;
                            _insert_dhcpd($pool."pf",$pf_ip->cidr());
                            my $last = $net->broadcast - 1;
                            while ($net <= $last) {
                                if ($net < $first ) {
                                    $net ++;
                                } else {
                                    _insert_dhcpd($pool,$net->addr());
                                    $net ++;
                                }
                            }
                        }
                    } else {
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
            } else {
                next;
            }
        }
    }
    close $fh;
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


=item freeradius_delete_dhcpd_lease

Delete dhcp lease in radippool table
 
=cut

sub freeradius_delete_dhcpd_lease {
    my ($mac) = @_;

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
        for my $interface (keys %{$host}) {
            next if ( ( $interface !~ /^interface (.*)/) || ($host->{$interface}->{type} ne 'internal') );
            my $eth = $1;
            my $password = sprintf("%02x%02x%02x%02x%02x%02x",int(rand(256)),int(rand(256)),int(rand(256)),int(rand(256)),int(rand(256)),int(rand(256)));
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
                Chaddr => $password,
                DHO_DHCP_MESSAGE_TYPE() => DHCPLEASEQUERY()
            );
            $password =~ s/([a-f0-9]{2})(?!$)/$1:/g;
            db_query_execute(DHCPD, $dhcpd_statements, 'freeradius_replace_password', 'password', $password, '0');
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
            $answer->{$host->{$interface}->{ip}} = \%info;
        }
    }
    db_query_execute(
            DHCPD, $dhcpd_statements, 'freeradius_delete_dhcpd_pool');
    if (defined($answer)) {
        for my $server (keys %{$answer}) {
            db_query_execute(
                DHCPD, $dhcpd_statements, 'freeradius_insert_dhcpd_pool', $server, $answer->{$server}{'interface'}, $answer->{$server}{'index'}
            );
        }
    }
}

=item dhcprole

Return dhcp attributes based on the role of the device

=cut

sub dhcprole {
    my ($dhcp) = @_;
    my $logger = get_logger();
    my $mac = $dhcp->{'chaddr'};
    my $node_info = node_attributes($mac);

    my $pf = dhcpd_pool_view_by_name($node_info->{category}.$dhcp->{'options'}->{225}."pf");
    my $current_network = NetAddr::IP->new( $pf->{'framedipaddress'} );
    my $radius_reply_ref = {
        'control:Pool-Name' => $node_info->{category}.$dhcp->{'options'}->{225},
        'DHCP-Subnet-Mask' => $current_network->mask(),
        'DHCP-Router-Address' => $current_network->addr(),
        'DHCP-DHCP-Server-Identifier' => $current_network->addr(),
    };
    my $status = $RADIUS::RLM_MODULE_OK;
    return [$status, %$radius_reply_ref];
}

=item dhcpd_pool_view_by_name

=cut

sub dhcpd_pool_view_by_name {
    my ($name) = @_;
    my $query = db_query_execute(DHCPD, $dhcpd_statements, 'freeradius_select_dhcpd_pool', $name);
    my $ref = $query->fetchrow_hashref();

    # just get one row and finish
    $query->finish();
    return ($ref);
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
