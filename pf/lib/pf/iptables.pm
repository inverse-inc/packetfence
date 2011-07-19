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

Readonly my $FW_FILTER_INPUT_INT_VLAN => 'input-internal-vlan-if';
Readonly my $FW_FILTER_INPUT_INT_INLINE => 'input-internal-inline-if';
Readonly my $FW_FILTER_INPUT_MGMT => 'input-management-if';
Readonly my $FW_FILTER_FORWARD_INT_INLINE => 'forward-internal-inline-if';
Readonly my $FW_PREROUTING_INT_INLINE => 'prerouting-internal-inline-if';

sub iptables_generate {
    my $logger = Log::Log4perl::get_logger('pf::iptables');

    my %tags = ( 
        'filter_if_src_to_chain' => '', 'filter_forward_inline' => '', 
        'mangle_if_src_to_chain' => '', 'mangle_prerouting_inline' => '', 
        'nat_if_src_to_chain' => '', 'nat_prerouting_inline' => '', 
    );

    # global substitution variables
    $tags{'web_admin_port'} = $Config{'ports'}{'admin'};
    # grabbing first management interface
    $tags{'mgmt_interface'} = $management_nets[0]->tag("int");

    # FILTER
    # per interface-type pointers to pre-defined chains
    $tags{'filter_if_src_to_chain'} = generate_filter_if_src_to_chain();

    # Note: I'm giving references to this guy here so he can directly mess with the tables
    generate_inline_rules(\$tags{'filter_forward_inline'}, \$tags{'nat_prerouting_inline'});

    # MANGLE
    $tags{'mangle_if_src_to_chain'} = generate_inline_if_src_to_chain();
    $tags{'mangle_prerouting_inline'} = generate_mangle_rules();

    # NAT chain targets and redirections (other rules injected by generate_inline_rules)
    $tags{'nat_if_src_to_chain'} = generate_inline_if_src_to_chain();
    $tags{'nat_prerouting_inline'} .= generate_nat_redirect_rules();

    chomp(
        $tags{'filter_if_src_to_chain'}, $tags{'filter_forward_inline'},
        $tags{'mangle_if_src_to_chain'}, $tags{'mangle_prerouting_inline'}, 
        $tags{'nat_if_src_to_chain'}, $tags{'nat_prerouting_inline'},
    );

    parse_template( \%tags, "$conf_dir/iptables.conf", "$generated_conf_dir/iptables.conf" );
    iptables_restore("$generated_conf_dir/iptables.conf");
}


=item generate_filter_if_src_to_chain

Creating proper source interface matches to jump to the right chains for proper enforcement method.

=cut
sub generate_filter_if_src_to_chain {
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    my $rules;

    # TODO extract in it's own sub
    # internal interfaces handling
    foreach my $interface (@internal_nets) {
        my $dev = $interface->tag("int");
        my $ip = $interface->tag("ip");
        my $enforcement_type = $Config{"interface $dev"}{'enforcement'};

        # VLAN enforcement
        if ($enforcement_type eq $IF_ENFORCEMENT_VLAN) {
            $rules .= "-A INPUT --in-interface $dev -d $ip --jump $FW_FILTER_INPUT_INT_VLAN\n";

        # inline enforcement
        } elsif ($enforcement_type eq $IF_ENFORCEMENT_INLINE) {
            $rules .= "-A INPUT --in-interface $dev -d $ip --jump $FW_FILTER_INPUT_INT_INLINE\n";
            $rules .= "-A FORWARD --in-interface $dev --jump $FW_FILTER_FORWARD_INT_INLINE\n";

        # nothing? something is wrong
        } else {
            $logger->warn("Didn't assign any firewall rules to interface $dev."); 
        }
    }

    # management interfaces handling
    foreach my $interface (@management_nets) {
        my $dev = $interface->tag("int");
        $rules .= "-A INPUT --in-interface $dev --jump $FW_FILTER_INPUT_MGMT\n";
    }
    
    return $rules;
}


=item generate_filter_input_listeners

=cut
# XXX NOT REIMPLEMENTED
sub generate_filter_input_listeners {
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    my $rules;

    # TODO to integrate and might need to adjust other tables too (NAT's dnat)
    my @listeners = split( /\s*,\s*/, $Config{'ports'}{'listeners'} );
    foreach my $listener (@listeners) {
        my $port = getservbyname( $listener, "tcp" );
        $rules .= "--protocol tcp --destination-port $port --jump ACCEPT\n";
    }
}

=item generate_inline_rules

Handling both FILTER and NAT tables at the same time.

=cut
sub generate_inline_rules {
    my ($filter_rules_ref, $nat_rules_ref) = @_;
    my $logger = Log::Log4perl::get_logger('pf::iptables');

    $logger->info("Allowing DNS through on inline interfaces to pre-configured DNS servers");
    foreach my $dns ( split( ",", $Config{'general'}{'dnsservers'} ) ) {
        my $rule = "--protocol udp --destination $dns --destination-port 53 --jump ACCEPT\n";
        $$filter_rules_ref .= "-A $FW_FILTER_FORWARD_INT_INLINE $rule";
        $$nat_rules_ref .= "-A $FW_PREROUTING_INT_INLINE $rule";
        $logger->trace("adding DNS FILTER passthrough for $dns");
    }

    # Accept marked users through
    $$filter_rules_ref .= "-A $FW_FILTER_FORWARD_INT_INLINE --match mark --mark 0x$reg_mark --jump ACCEPT\n";
}

=item generate_filter_forward_vlan

=cut
# XXX not sure it'll be useful
sub generate_filter_forward_vlan {
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    my $rules;

    return $rules;
}

=item generate_filter_forward_scanhost

=cut
# XXX NOT REIMPLEMENTED
sub generate_filter_forward_scanhost {
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    my $filter_rules;

    # FIXME don't forget to also add statements to the PREROUTING nat table as in generate_inline_rules
    my $scan_server = $Config{'scan'}{'host'};
    if ( $scan_server !~ /^127\.0\.0\.1$/ && $scan_server !~ /^localhost$/i ) {
        $filter_rules .= internal_append_entry( "-A FORWARD --destination $scan_server --jump ACCEPT");
        $filter_rules .= external_append_entry( "-A FORWARD --source $scan_server --jump ACCEPT");
        $logger->info("adding Nessus FILTER passthrough for $scan_server");
    }

    return $filter_rules;
}

=item generate_passthrough

=cut
# XXX NOT REIMPLEMENTED
# FIXME don't forget to also add statements to the PREROUTING nat table as in generate_inline_rules
sub generate_passthrough {
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    my $filter_rules;

    # poke passthroughs
    my %passthroughs =  %{ $Config{'passthroughs'} } if ( $Config{'trapping'}{'passthrough'} =~ /^iptables$/i );
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

=item generate_inline_if_src_to_chain

Creating proper source interface matches to jump to the right chains for inline enforcement method.

=cut
sub generate_inline_if_src_to_chain {
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    my $rules;

    # internal interfaces handling
    foreach my $interface (@internal_nets) {
        my $dev = $interface->tag("int");
        my $ip = $interface->tag("ip");
        my $enforcement_type = $Config{"interface $dev"}{'enforcement'};

        # inline enforcement
        if ($enforcement_type eq $IF_ENFORCEMENT_INLINE) {
            $rules .= "-A PREROUTING --in-interface $dev --jump $FW_PREROUTING_INT_INLINE\n";
        }
    }

    return $rules;
}

=item generate_mangle_rules

=cut
sub generate_mangle_rules {
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    my $mangle_rules;

    # mark all users
    $mangle_rules .= "-A $FW_PREROUTING_INT_INLINE --jump MARK --set-mark 0x$unreg_mark\n";

    # mark all registered users
    # XXX we will need to mark all registered users with last locationlog set to
    if ( isenabled($Config{'trapping'}{'registration'}) ) {
        require pf::node;
        my @registered = pf::node::nodes_registered();
        foreach my $row (@registered) {
            my $mac = $row->{'mac'};
            $mangle_rules .= 
                "-A $FW_PREROUTING_INT_INLINE --match mac --mac-source $mac " . 
                "--jump MARK --set-mark 0x$reg_mark\n"
            ;
        }
    }

    # mark whitelisted users
    foreach my $mac ( split( /\s*,\s*/, $Config{'trapping'}{'whitelist'} ) ) {
        $mangle_rules .= 
            "-A $FW_PREROUTING_INT_INLINE --match mac --mac-source $mac --jump MARK --set-mark 0x$reg_mark\n"
        ;
    }

    # mark all open violations
    my @macarray = violation_view_open_all();
    if ( $macarray[0] ) {
        foreach my $row (@macarray) {
            my $mac = $row->{'mac'};
            my $vid = $row->{'vid'};
            $mangle_rules .= 
                "-A $FW_PREROUTING_INT_INLINE --match mac --mac-source $mac --jump MARK --set-mark 0x$vid\n"
            ;
        }
    }

    # mark blacklisted users
    foreach my $mac ( split( /\s*,\s*/, $Config{'trapping'}{'blacklist'} ) ) {
        $mangle_rules .= 
            "-A $FW_PREROUTING_INT_INLINE --match mac --mac-source $mac --jump MARK --set-mark $black_mark\n"
        ;
    }

    return $mangle_rules;
}

=item generate_nat_redirect_rules

=cut
sub generate_nat_redirect_rules {
    my $logger = Log::Log4perl::get_logger('pf::iptables');
    my $rules;

    # how we do our magic
    foreach my $redirectport ( split( /\s*,\s*/, $Config{'ports'}{'redirect'} ) ) {
        my ( $port, $protocol ) = split( "/", $redirectport );
        if ( isenabled( $Config{'trapping'}{'registration'} ) ) {
            $rules .= 
                "-A $FW_PREROUTING_INT_INLINE --protocol $protocol --destination-port $port " . 
                "--match mark --mark 0x$unreg_mark --jump REDIRECT\n"
            ;
        }

        my @trapvids = class_trappable();
        foreach my $row (@trapvids) {
            my $vid = $row->{'vid'};
            $rules .=
                "-A $FW_PREROUTING_INT_INLINE --protocol $protocol --destination-port $port " . 
                "--match mark --mark 0x$vid --jump REDIRECT\n"
            ;
        }
    }

    return $rules;
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

Olivier Bilodeau <obilodeau@inverse.ca>

David LaPorte <david@davidlaporte.org>

Kevin Amorin <kev@amorin.org>

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
