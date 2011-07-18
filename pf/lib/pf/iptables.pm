package pf::iptables;

=head1 NAME

pf::iptables - module for iptables rules management.

=cut

=head1 DESCRIPTION

pf::iptables contains the functions necessary to manipulate the 
iptables rules used when using PacketFence in ARP or DHCP mode.

=head1 CONFIGURATION AND ENVIRONMENT

F<pf.conf> configuration file and iptables template F<iptables.conf>.

=cut

use strict;
use warnings;

use IPTables::ChainMgr;
use Log::Log4perl;
use Readonly;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        iptables_generate iptables_save iptables_restore iptables_mark_node iptables_unmark_node
    );
}

use pf::class qw(class_view_all class_trappable);
use pf::config;
use pf::util;
use pf::violation qw(violation_view_open_all violation_count);

Readonly my %ALLOWED_SERVICES => (
    'internal' => [
        ['dns', 'udp', 53],
        ['dhcp', 'tcp', 67],
        ['dhcp', 'udp', 67],
        ['http', 'tcp', 80],
        ['https', 'tcp', 443],
    ],
);

# XXX merge with above structure
Readonly my %ALLOW_TCP_SERVICE_MGMT_IF => (
    'pf-admin' => 1443,
    'radius' => 1812,
    'radius-acct' => 1813,
);

Readonly my %ALLOW_UDP_SERVICE_MGMT_IF => (
    'snmptrap' => 162,
    'radius' => 1812,
    'radius-acct' => 1813,
);

sub iptables_generate {
    my $logger = Log::Log4perl::get_logger('pf::iptables');

    my %tags = ( 'filter_rules' => '', 'mangle_rules' => '', 'nat_rules' => '' );

    # initialize mangle table
#    $tags{'mangle_rules'} = generate_mangle_rules();

    # initialize filter table
    $tags{'filter_rules'} = generate_filter_rules();

    # initialize nat table
#    $tags{'nat_rules'} = generate_nat_rules();

    chomp( $tags{'mangle_rules'} );
    chomp( $tags{'filter_rules'} );
    chomp( $tags{'nat_rules'} );

    parse_template( \%tags, "$conf_dir/iptables.conf", "$generated_conf_dir/iptables.conf" );
    iptables_restore("$generated_conf_dir/iptables.conf");
}

=item generate_mangle_rules

=cut
sub generate_mangle_rules {
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    my $mangle_rules;

    # mark all users
    $mangle_rules .= "-A PREROUTING --jump MARK --set-mark 0x$unreg_mark\n";

    # mark all registered users
    # XXX we will need to mark all registered users with last locationlog set to
    if ( isenabled($Config{'trapping'}{'registration'}) ) {
        require pf::node;
        my @registered = pf::node::nodes_registered();
        foreach my $row (@registered) {
            my $mac = $row->{'mac'};
            $mangle_rules .= "-A PREROUTING --match mac --mac-source $mac --jump MARK --set-mark 0x$reg_mark\n";
        }
    }

    # mark whitelisted users
    foreach my $mac ( split( /\s*,\s*/, $Config{'trapping'}{'whitelist'} ) ) {
        $mangle_rules .= "-A PREROUTING --match mac --mac-source $mac --jump MARK --set-mark 0x$reg_mark\n";
    }

    # mark all open violations
    my @macarray = violation_view_open_all();
    if ( $macarray[0] ) {
        foreach my $row (@macarray) {
            my $mac = $row->{'mac'};
            my $vid = $row->{'vid'};
            $mangle_rules .= "-A PREROUTING --match mac --mac-source $mac --jump MARK --set-mark 0x$vid\n";
        }
    }

    # mark blacklisted users
    foreach my $mac ( split( /\s*,\s*/, $Config{'trapping'}{'blacklist'} ) ) {
        $mangle_rules .= "-A PREROUTING --match mac --mac-source $mac --jump MARK --set-mark $black_mark\n";
    }

    return $mangle_rules;
}

=item generate_filter_rules

=cut
sub generate_filter_rules {
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    my $filter_rules;

    # open up loopback
    $filter_rules .= "-A INPUT --in-interface lo --jump ACCEPT\n";

    # adding allowed tcp and udp services on internal interfaces
    foreach my $if_type (keys %ALLOWED_SERVICES) {
        my @if_list;

        if ($if_type eq $pf::config::IF_INTERNAL) {
            @if_list = @internal_nets;
        } else {
           $logger->warn("Unknown interface type $if_type. Some firewall rules might be broken"); 
        }

        foreach my $rule (@{$ALLOWED_SERVICES{$if_type}}) {
            my ($service, $proto, $port) = @$rule;
            $logger->trace("Adding to filter allow $service on $if_type interfaces for proto $proto port $port");

            foreach my $interface (@if_list) {
                my $dev = $interface->tag("int");

                $filter_rules .= 
                    "-A INPUT --in-interface $dev --protocol $proto --destination-port $port --jump ACCEPT\n";
            }
        }
    }
    return $filter_rules;
#
#    # adding allowed tcp and udp services on internal interfaces
#    foreach my $service (keys %ALLOW_TCP_SERVICE_INTERNAL_IF) {
#        $logger->trace("Adding to filter allow tcp $service ($ALLOW_TCP_SERVICE_INTERNAL_IF{$service})");
#        $filter_rules .= internal_append_entry(
#            "-A INPUT --protocol tcp --destination-port $ALLOW_TCP_SERVICE_INTERNAL_IF{$service} --jump ACCEPT"
#        );
#    }
#
#    # adding allowed udp services on internal interfaces
#    foreach my $service (keys %ALLOW_UDP_SERVICE_INTERNAL_IF) {
#        $logger->trace("Adding to filter allow udp $service ($ALLOW_UDP_SERVICE_INTERNAL_IF{$service})");
#        $filter_rules .= internal_append_entry(
#            "-A INPUT --protocol udp --destination-port $ALLOW_UDP_SERVICE_INTERNAL_IF{$service} --jump ACCEPT"
#        );
#    }

    # TODO keep or drop?
    my @listeners = split( /\s*,\s*/, $Config{'ports'}{'listeners'} );
    foreach my $listener (@listeners) {
        my $port = getservbyname( $listener, "tcp" );
        $filter_rules .= internal_append_entry("-A INPUT --protocol tcp --destination-port $port --jump ACCEPT");
    }

    # open ports
    $filter_rules .= managed_append_entry("-A INPUT --protocol icmp --icmp-type 8 --jump ACCEPT");
    $filter_rules .= managed_append_entry(
        "-A INPUT --protocol tcp --destination-port " . $Config{'ports'}{'admin'} . " --jump ACCEPT"
    );
    $filter_rules .= managed_append_entry("-A INPUT --protocol tcp --destination-port 22 --jump ACCEPT");

    # accept already established connections
    foreach my $out_dev ( get_internal_devs() ) {
        $filter_rules .= external_append_entry(
            "-A FORWARD --match state --state RELEATED,ESTABLISHED --out-interface $out_dev --jump ACCEPT"
        );
    }

    # allowed tcp ports
    foreach my $dns ( split( ",", $Config{'general'}{'dnsservers'} ) ) {
        $filter_rules .= internal_append_entry(
            "-A FORWARD --protocol udp --destination $dns --destination-port 53 --jump ACCEPT"
        );
        $logger->info("adding DNS FILTER passthrough for $dns");
    }

    my $scan_server = $Config{'scan'}{'host'};
    if ( $scan_server !~ /^127\.0\.0\.1$/ && $scan_server !~ /^localhost$/i ) {
        $filter_rules .= internal_append_entry( "-A FORWARD --destination $scan_server --jump ACCEPT");
        $filter_rules .= external_append_entry( "-A FORWARD --source $scan_server --jump ACCEPT");
        $logger->info("adding Nessus FILTER passthrough for $scan_server");
    }

    # poke passthroughs
    my %passthroughs;
    %passthroughs = %{ $Config{'passthroughs'} } if ( $Config{'trapping'}{'passthrough'} =~ /^iptables$/i );
    $passthroughs{'trapping.redirecturl'} = $Config{'trapping'}{'redirecturl'} if ($Config{'trapping'}{'redirecturl'});
    foreach my $passthrough ( keys %passthroughs ) {
        if ( $passthroughs{$passthrough} =~ /^(http|https):\/\// ) {
            my $destination;
            my ($service, $host, $port, $path) = 
                $passthroughs{$passthrough} =~ /^(\w+):\/\/(.+?)(:\d+){0,1}(\/.*){0,1}$/;
            $port =~ s/:// if $port;

            $port = 80  if ( !$port && $service =~ /^http$/i );
            $port = 443 if ( !$port && $service =~ /^https$/i );

            my ( $name, $aliases, $addrtype, $length, @addrs ) = gethostbyname($host);
            if ( !@addrs ) {
                $logger->error("unable to resolve $host for passthrough");
                next;
            }
            foreach my $addr (@addrs) {
                $destination = join( ".", unpack( 'C4', $addr ) );
                $filter_rules
                    .= internal_append_entry(
                    "-A FORWARD --protocol tcp --destination $destination --destination-port $port --jump ACCEPT"
                    );
                $logger->info("adding FILTER passthrough for $passthrough");
            }
        } elsif ( $passthroughs{$passthrough} =~ /^(\d{1,3}.){3}\d{1,3}(\/\d+){0,1}$/ ) {
            $logger->info("adding FILTER passthrough for $passthrough");
            $filter_rules .= internal_append_entry( 
                "-A FORWARD --destination " . $passthroughs{$passthrough} . " --jump ACCEPT"
            );
        } else {
            $logger->error("unrecognized passthrough $passthrough");
        }
    }

    # poke holes for content URLs
    # can we collapse with above?
    if ( $Config{'trapping'}{'passthrough'} eq "iptables" ) {
        my @contents = class_view_all();
        foreach my $content (@contents) {
            my $vid            = $content->{'vid'};
            my $url            = $content->{'url'};
            my $max_enable_url = $content->{'max_enable_url'};
            my $redirect_url   = $content->{'redirect_url'};

            foreach my $u ( $url, $max_enable_url, $redirect_url ) {

                # local content or null URLs
                next if ( !$u || $u =~ /^\// );
                if ( $u !~ /^(http|https):\/\// ) {
                    $logger->error("vid $vid: unrecognized content URL: $u");
                    next;
                }

                my $destination;
                my ( $service, $host, $port, $path ) = $u =~ /^(\w+):\/\/(.+?)(:\d+){0,1}(\/.*){0,1}$/;

                $port =~ s/:// if $port;

                $port = 80  if ( !$port && $service =~ /^http$/i );
                $port = 443 if ( !$port && $service =~ /^https$/i );

                my ( $name, $aliases, $addrtype, $length, @addrs ) = gethostbyname($host);
                if ( !@addrs ) {
                    $logger->error("unable to resolve $host for content passthrough");
                    next;
                }
                foreach my $addr (@addrs) {
                    $destination = join( ".", unpack( 'C4', $addr ) );
                    $filter_rules .= internal_append_entry(
                        "-A FORWARD --protocol tcp --destination $destination --destination-port $port --match mark --mark 0x$vid --jump ACCEPT"
                    );
                    $logger->info("adding FILTER passthrough for $destination:$port");
                }
            }
        }
    }

    my @trapvids = class_trappable();
    foreach my $row (@trapvids) {
        my $vid = $row->{'vid'};
        $filter_rules .= internal_append_entry("-A FORWARD --match mark --mark 0x$vid --jump DROP");
    }

    # allowed established sessions from pf box
    $filter_rules .= "-A INPUT --match state --state RELATED,ESTABLISHED --jump ACCEPT\n";

    return $filter_rules;
}

=item generate_nat_rules

=cut
sub generate_nat_rules {
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    my $nat_rules;

    foreach my $dns ( split( ",", $Config{'general'}{'dnsservers'} ) ) {
        $nat_rules .= internal_append_entry(
            "-A PREROUTING --protocol udp --destination $dns --destination-port 53 --jump ACCEPT"
        );
        $logger->info("adding DNS NAT passthrough for $dns");
    }

    $logger->info("adding DHCP NAT passthrough");
    $nat_rules .= internal_append_entry(
        "-A PREROUTING --protocol udp --destination-port 67 --jump ACCEPT"
    );

    my $scan_server = $Config{'scan'}{'host'};
    if ( $scan_server !~ /^127\.0\.0\.1$/ && $scan_server !~ /^localhost$/i ) {
        $logger->info("adding Nessus NAT passthrough for $scan_server");
        $nat_rules .= internal_append_entry("-A PREROUTING --destination $scan_server --jump ACCEPT");
        $nat_rules .= internal_append_entry("-A PREROUTING --source $scan_server --jump ACCEPT");
    }

    # poke passthroughs
    my %passthroughs;
    %passthroughs = %{ $Config{'passthroughs'} } if ( $Config{'trapping'}{'passthrough'} =~ /^iptables$/i );
    $passthroughs{'trapping.redirecturl'} = $Config{'trapping'}{'redirecturl'} if ($Config{'trapping'}{'redirecturl'});

    foreach my $passthrough ( keys %passthroughs ) {
        if ( $passthroughs{$passthrough} =~ /^(http|https):\/\// ) {
            my $destination;
            my ( $service, $host, $port, $path ) = 
                $passthroughs{$passthrough} =~ /^(\w+):\/\/(.+?)(:\d+){0,1}(\/.*){0,1}$/;
            $port =~ s/:// if $port;

            $port = 80  if ( !$port && $service =~ /^http$/i );
            $port = 443 if ( !$port && $service =~ /^https$/i );

            my ( $name, $aliases, $addrtype, $length, @addrs ) = gethostbyname($host);
            if ( !@addrs ) { $logger->error("unable to resolve $host for passthrough");
                next;
            }
            foreach my $addr (@addrs) {
                $destination = join( ".", unpack( 'C4', $addr ) );
                $nat_rules .= internal_append_entry(
                    "-A PREROUTING --protocol tcp --destination $destination --destination-port $port --jump ACCEPT"
                );
                $logger->info("adding NAT passthrough for $passthrough");
            }
        } elsif ( $passthroughs{$passthrough} =~ /^(\d{1,3}.){3}\d{1,3}(\/\d+){0,1}$/ ) {

            $nat_rules .= internal_append_entry( 
                "-A PREROUTING --destination " . $passthroughs{$passthrough} . " --jump ACCEPT"
            );
            $logger->info("adding NAT passthrough for $passthrough");
        } else {
            $logger->error("unrecognized passthrough $passthrough");
        }
    }

    # poke holes for content URLs
    # can we collapse with above?
    if ( $Config{'trapping'}{'passthrough'} eq "iptables" ) {
        my @contents = class_view_all();
        foreach my $content (@contents) {
            my $vid            = $content->{'vid'};
            my $url            = $content->{'url'};
            my $max_enable_url = $content->{'max_enable_url'};
            my $redirect_url   = $content->{'redirect_url'};

            foreach my $u ( $url, $max_enable_url, $redirect_url ) {

                # local content or null URLs
                next if ( !$u || $u =~ /^\// );
                if ( $u !~ /^(http|https):\/\// ) {
                    $logger->error("vid $vid: unrecognized content URL: $u");
                    next;
                }

                my $destination;
                my ( $service, $host, $port, $path ) = $u =~ /^(\w+):\/\/(.+?)(:\d+){0,1}(\/.*){0,1}$/;

                $port =~ s/:// if $port;

                $port = 80  if ( !$port && $service =~ /^http$/i );
                $port = 443 if ( !$port && $service =~ /^https$/i );

                my ( $name, $aliases, $addrtype, $length, @addrs ) = gethostbyname($host);
                if ( !@addrs ) {
                    $logger->error( "unable to resolve $host for content passthrough");
                    next;
                }
                foreach my $addr (@addrs) {
                    $destination = join( ".", unpack( 'C4', $addr ) );
                    $nat_rules .= internal_append_entry(
                        "-A PREROUTING --protocol tcp --destination $destination --destination-port $port --match mark --mark 0x$vid --jump ACCEPT"
                    );
                    $logger->info("adding NAT passthrough for $destination:$port");
                }
            }
        }
    }

    # how we do our magic
    foreach my $redirectport ( split( /\s*,\s*/, $Config{'ports'}{'redirect'} ) ) {
        my ( $port, $protocol ) = split( "/", $redirectport );
        if ( isenabled( $Config{'trapping'}{'registration'} ) ) {
            $nat_rules .= internal_append_entry(
                "-A PREROUTING --protocol $protocol --destination-port $port --match mark --mark 0x$unreg_mark --jump REDIRECT"
            );
        }

        my @trapvids = class_trappable();
        foreach my $row (@trapvids) {
            my $vid = $row->{'vid'};
            $nat_rules .= internal_append_entry(
                "-A PREROUTING --protocol $protocol --destination-port $port --match mark --mark 0x$vid --jump REDIRECT"
            );
        }
    }

    return $nat_rules;
}

sub external_append_entry {
    my ($cmd_arg)    = @_;
    my $logger       = Log::Log4perl::get_logger('pf::iptables');
    my $returnString = '';
    foreach my $dev ( get_external_devs() ) {
        my $cmd_arg_tmp = $cmd_arg;
        $cmd_arg_tmp  .= " --in-interface $dev";
        $returnString .= "$cmd_arg_tmp\n";
    }
    return $returnString;
}

sub iptables_mark_node {
    my ( $mac, $mark ) = @_;
    my $logger   = Log::Log4perl::get_logger('pf::iptables');
    my $iptables = new IPTables::ChainMgr()
        || logger->logcroak("unable to create IPTables::ChainMgr object");
    my $iptables_cmd = $iptables->{'_iptables'};

    if (!$iptables->run_ipt_cmd(
            "$iptables_cmd -t mangle -A PREROUTING --match mac --mac-source $mac --jump MARK --set-mark 0x$mark"
        )
        )
    {
        $logger->error("unable to mark $mac with $mark: $!");
        return (0);
    }
    return (1);
}

sub iptables_unmark_node {
    my ( $mac, $mark ) = @_;
    my $logger   = Log::Log4perl::get_logger('pf::iptables');
    my $iptables = new IPTables::ChainMgr()
        || logger->logcroak("unable to create IPTables::ChainMgr object");
    my $iptables_cmd = $iptables->{'_iptables'};

    if (!$iptables->run_ipt_cmd(
            "$iptables_cmd -t mangle -D PREROUTING --match mac --mac-source $mac --jump MARK --set-mark 0x$mark"
        )
        )
    {
        $logger->error("unable to unmark $mac with $mark: $!");
        return (0);
    }

    return (1);
}

sub iptables_save {
    my ($save_file) = @_;
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    $logger->info( "saving existing iptables to " . $save_file );
    `/sbin/iptables-save -t nat > $save_file`;
    `/sbin/iptables-save -t mangle >> $save_file`;
    `/sbin/iptables-save -t filter >> $save_file`;
}

sub iptables_restore {
    my ($restore_file) = @_;
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    if ( -r $restore_file ) {
        $logger->info( "restoring iptables from " . $restore_file );
        `/sbin/iptables-restore < $restore_file`;
    }
}

sub iptables_restore_noflush {
    my ($restore_file) = @_;
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    if ( -r $restore_file ) {
        $logger->info(
            "restoring iptables (no flush) from " . $restore_file );
        `/sbin/iptables-restore -n < $restore_file`;
    }
}

=head1 AUTHOR

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005 David LaPorte

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2011 Inverse inc.

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
