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

use IO::Interface::Simple;
use pf::log;
use Readonly;
use NetAddr::IP;
use pf::constants;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        iptables_generate iptables_save iptables_restore
        iptables_mark_node iptables_unmark_node get_mangle_mark_for_mac update_mark
    );
}

use pf::config qw(
    %ConfigNetworks
    %Config
    $IPTABLES_MARK_UNREG
    $management_network
    @internal_nets
    $IF_ENFORCEMENT_VLAN
    %ConfigProvisioning
    $IF_ENFORCEMENT_DNS
    @portal_ints
    @ha_ints
    $IPTABLES_MARK_ISOLATION
    $IPTABLES_MARK_REG
    is_inline_enforcement_enabled
    is_type_inline
    @radius_ints
);
use pf::file_paths qw($generated_conf_dir $conf_dir);
use pf::util;
use pf::violation qw(violation_view_open_uniq violation_count);
use pf::authentication;
use pf::cluster;
use pf::ConfigStore::Provisioning;
use pf::ConfigStore::Domain;

# This is the content that needs to match in the iptable rules for the service
# to be considered as running
Readonly our $FW_FILTER_INPUT_MGMT      => 'input-management-if';
Readonly our $FW_FILTER_INPUT_PORTAL    => 'input-portal-if';
Readonly our $FW_FILTER_INPUT_RADIUS    => 'input-radius-if';

Readonly my $FW_TABLE_FILTER => 'filter';
Readonly my $FW_TABLE_MANGLE => 'mangle';
Readonly my $FW_TABLE_NAT => 'nat';
Readonly my $FW_FILTER_INPUT_INT_VLAN => 'input-internal-vlan-if';
Readonly my $FW_FILTER_INPUT_INT_ISOL_VLAN => 'input-internal-isol_vlan-if';
Readonly my $FW_FILTER_INPUT_INT_INLINE => 'input-internal-inline-if';
Readonly my $FW_FILTER_INPUT_INT_HA => 'input-highavailability-if';
Readonly my $FW_FILTER_FORWARD_INT_INLINE => 'forward-internal-inline-if';
Readonly my $FW_FILTER_FORWARD_INT_VLAN => 'forward-internal-vlan-if';
Readonly my $FW_FILTER_FORWARD_INT_ISOL_VLAN => 'forward-internal-isolvlan-if';
Readonly my $FW_PREROUTING_INT_INLINE => 'prerouting-int-inline-if';
Readonly my $FW_POSTROUTING_INT_INLINE => 'postrouting-int-inline-if';
Readonly my $FW_POSTROUTING_INT_INLINE_ROUTED => 'postrouting-inline-routed';
Readonly my $FW_PREROUTING_INT_VLAN => 'prerouting-int-vlan-if';

=head1 SUBROUTINES

TODO: This list is incomplete

=over

=cut

=item new

Constructor

=cut

sub new {
   my $logger = get_logger();
   $logger->debug("instantiating new pf::iptables object");
   my ( $class, %argv ) = @_;
   my $self = bless {}, $class;
   return $self;
}


sub iptables_generate {
    my ($self) = @_;
    my $logger = get_logger();
    my %tags = (
        'filter_if_src_to_chain' => '', 'filter_forward_inline' => '',
        'filter_forward_vlan' => '', 'filter_forward_domain' => '',
        'mangle_if_src_to_chain' => '', 'mangle_prerouting_inline' => '',
        'nat_if_src_to_chain' => '', 'nat_prerouting_inline' => '',
        'nat_postrouting_vlan' => '', 'nat_postrouting_inline' => '',
        'input_inter_inline_rules' => '', 'nat_prerouting_vlan' => '',
        'routed_postrouting_inline' => '','input_inter_vlan_if' => '',
        'domain_postrouting' => '','mangle_postrouting_inline' => '',
        'filter_forward_isol_vlan' => '', 'input_inter_isol_vlan_if' => '',
    );

    # global substitution variables
    $tags{'web_admin_port'} = $Config{'ports'}{'admin'};
    $tags{'webservices_port'} = $Config{'ports'}{'soap'};
    $tags{'aaa_port'} = $Config{'ports'}{'aaa'};
    $tags{'httpd_portal_modstatus'} = $Config{'ports'}{'httpd_portal_modstatus'};
    $tags{'httpd_collector_port'} = $Config{'ports'}{'collector'};
    # FILTER
    # per interface-type pointers to pre-defined chains
    $tags{'filter_if_src_to_chain'} .= $self->generate_filter_if_src_to_chain();

    # eduroam RADIUS virtual-server
    if ( @{pf::authentication::getAuthenticationSourcesByType('Eduroam')} ) {
        my @eduroam_authentication_source = @{pf::authentication::getAuthenticationSourcesByType('Eduroam')};
        my $eduroam_listening_port = $eduroam_authentication_source[0]{'auth_listening_port'};    # using array index 0 since there can only be one 'eduroam' authentication source ('unique' attribute)
        $tags{'eduroam_radius_virtualserver'} = "-A input-management-if --protocol tcp --match tcp --dport $eduroam_listening_port --jump ACCEPT\n";
        $tags{'eduroam_radius_virtualserver'} .= "-A input-management-if --protocol udp --match udp --dport $eduroam_listening_port --jump ACCEPT\n";
        $tags{'eduroam_radius_listening'} = "-A input-radius-if --protocol tcp --match tcp --dport $eduroam_listening_port --jump ACCEPT\n";
        $tags{'eduroam_radius_listening'} .= "-A input-radius-if --protocol udp --match udp --dport $eduroam_listening_port --jump ACCEPT\n";
    }
    else {
        $tags{'eduroam_radius_virtualserver'} = "# eduroam integration is not configured\n";
        $tags{'eduroam_radius_listening'} = "# eduroam integration is not configured\n";
    }

    if (is_inline_enforcement_enabled()) {
        # Note: I'm giving references to this guy here so he can directly mess with the tables
        $self->generate_inline_rules(
            \$tags{'filter_forward_inline'}, \$tags{'nat_prerouting_inline'}, \$tags{'nat_postrouting_inline'},\$tags{'routed_postrouting_inline'},\$tags{'input_inter_inline_rules'}
        );

        # MANGLE
        $tags{'mangle_if_src_to_chain'} .= $self->generate_inline_if_src_to_chain($FW_TABLE_MANGLE);
        $tags{'mangle_prerouting_inline'} .= $self->generate_mangle_rules();                # TODO: These two should be combined... 2015.05.25 dwuelfrath@inverse.ca
        $tags{'mangle_postrouting_inline'} .= $self->generate_mangle_postrouting_rules();   # TODO: These two should be combined... 2015.05.25 dwuelfrath@inverse.ca

        # NAT chain targets and redirections (other rules injected by generate_inline_rules)
        $tags{'nat_if_src_to_chain'} .= $self->generate_inline_if_src_to_chain($FW_TABLE_NAT);
        $tags{'nat_prerouting_inline'} .= $self->generate_nat_redirect_rules();
    }

    #NAT Intercept Proxy
    $self->generate_interception_rules(\$tags{'nat_if_src_to_chain'},\$tags{'nat_prerouting_vlan'},\$tags{'input_inter_vlan_if'} );

    # OAuth
    my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));

    if ($passthrough_enabled) {
        generate_passthrough_rules(
            $passthrough_enabled,\$tags{'filter_forward_vlan'},\$tags{'nat_postrouting_vlan'},\$tags{'filter_forward_isol_vlan'}
        );
    }

    chomp(
        $tags{'filter_if_src_to_chain'}, $tags{'filter_forward_inline'},
        $tags{'mangle_if_src_to_chain'}, $tags{'mangle_prerouting_inline'},
        $tags{'nat_if_src_to_chain'}, $tags{'nat_prerouting_inline'},
  );

    generate_domain_rules(\$tags{'filter_forward_domain'}, \$tags{'domain_postrouting'});

    # HTTP parking related rule
    $tags{'nat_prerouting_vlan'} .= "-A PREROUTING -p tcp --dport 80 -m set --match-set $pf::constants::parking::PARKING_IPSET_NAME src -j REDIRECT --to-port 5252\n";
    $tags{'nat_prerouting_vlan'} .= "-A PREROUTING -p tcp --dport 443 -m set --match-set $pf::constants::parking::PARKING_IPSET_NAME src -j REDIRECT --to-port 5252\n";

    parse_template( \%tags, "$conf_dir/iptables.conf", "$generated_conf_dir/iptables.conf" );
    $self->iptables_restore("$generated_conf_dir/iptables.conf");
}


=item generate_filter_if_src_to_chain

Creating proper source interface matches to jump to the right chains for proper enforcement method.

=cut

sub generate_filter_if_src_to_chain {
    my ($self) = @_;
    my $logger = get_logger();
    my $rules = '';

    my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));
    my $isolation_passthrough_enabled = isenabled($Config{'fencing'}{'isolation_passthrough'});

    # internal interfaces handling
    foreach my $interface (@internal_nets) {
        my $dev = $interface->tag("int");
        my $ip = $interface->tag("vip") || $interface->tag("ip");
        my $enforcement_type = $Config{"interface $dev"}{'enforcement'};

        my $cluster_ip = $ConfigCluster{$CLUSTER}->{"interface $dev"}->{ip};
        # VLAN enforcement
        if ($enforcement_type eq $IF_ENFORCEMENT_VLAN || $enforcement_type eq $IF_ENFORCEMENT_DNS) {
            if ($dev =~ m/(\w+):\d+/) {
                $dev = $1;
            }
            my $type = $pf::config::NET_TYPE_VLAN_REG;
            my $chain = $FW_FILTER_INPUT_INT_VLAN;
            foreach my $network ( keys %ConfigNetworks ) {
                # We skip non-inline networks/interfaces
                next if ( pf::config::is_network_type_inline($network) );
                if ( $ConfigNetworks{$network}{'type'} eq $pf::config::NET_TYPE_VLAN_ISOL ) {
                    my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
                    my $ip_test = new NetAddr::IP::Lite clean_ip($ip);
                    if ($net_addr->contains($ip_test)) {
                        $chain = $FW_FILTER_INPUT_INT_ISOL_VLAN;
                        $type = $pf::config::NET_TYPE_VLAN_ISOL;
                    }
                }
            }
            $rules .= "-A INPUT --in-interface $dev -d 224.0.0.0/8 -j ACCEPT\n";
            $rules .= "-A INPUT --in-interface $dev -p vrrp -j ACCEPT\n";
            $rules .= "# DHCP Sync\n";
            $rules .= "-A INPUT --in-interface $dev --protocol tcp --match tcp --dport 647 -j ACCEPT\n" if ($pf::cluster_enabled);
            $rules .= "-A INPUT --in-interface $dev --protocol udp --match udp --dport 67 -j ACCEPT\n";
            $rules .= "-A INPUT --in-interface $dev -d ".$cluster_ip." --jump $FW_FILTER_INPUT_INT_VLAN\n" if ($cluster_enabled);
            $rules .= "-A INPUT --in-interface $dev -d " . $interface->tag("vip") . " --jump $FW_FILTER_INPUT_INT_VLAN\n" if $interface->tag("vip");
            $rules .= "-A INPUT --in-interface $dev -d " . $interface->tag("ip") . " --jump $FW_FILTER_INPUT_INT_VLAN\n";
            $rules .= "-A INPUT --in-interface $dev -d 255.255.255.255 --jump $FW_FILTER_INPUT_INT_VLAN\n";
            if ($passthrough_enabled && ($type eq $pf::config::NET_TYPE_VLAN_REG)) {
                $rules .= "-A FORWARD --in-interface $dev --jump $FW_FILTER_FORWARD_INT_VLAN\n";
                $rules .= "-A FORWARD --out-interface $dev --jump $FW_FILTER_FORWARD_INT_VLAN\n";
            }
            if ($isolation_passthrough_enabled && ($type eq $pf::config::NET_TYPE_VLAN_ISOL)) { 
                $rules .= "-A FORWARD --in-interface $dev --jump $FW_FILTER_FORWARD_INT_ISOL_VLAN\n";
                $rules .= "-A FORWARD --out-interface $dev --jump $FW_FILTER_FORWARD_INT_ISOL_VLAN\n";
            }

        # inline enforcement
        } elsif (is_type_inline($enforcement_type)) {
            my $mgmt_ip = (defined($management_network->tag('vip'))) ? $management_network->tag('vip') : $management_network->tag('ip');
            $rules .= "-A INPUT --in-interface $dev -d 224.0.0.0/8 -j ACCEPT\n";
            $rules .= "-A INPUT --in-interface $dev -p vrrp -j ACCEPT\n";
            $rules .= "# DHCP Sync\n";
            $rules .= "-A INPUT --in-interface $dev --protocol tcp --match tcp --dport 647 -j ACCEPT\n" if ($cluster_enabled);
            $rules .= "-A INPUT --in-interface $dev --protocol udp --match udp --dport 67 -j ACCEPT\n";
            $rules .= "-A INPUT --in-interface $dev -d ".$cluster_ip." --jump $FW_FILTER_INPUT_INT_INLINE\n" if ($cluster_enabled);
            $rules .= "-A INPUT --in-interface $dev --protocol udp --match udp --dport 53 --jump $FW_FILTER_INPUT_INT_INLINE\n";
            $rules .= "-A INPUT --in-interface $dev --protocol tcp --match tcp --dport 53 --jump $FW_FILTER_INPUT_INT_INLINE\n";
            $rules .= "-A INPUT --in-interface $dev -d $ip --jump $FW_FILTER_INPUT_INT_INLINE\n";
            $rules .= "-A INPUT --in-interface $dev -d 255.255.255.255 --jump $FW_FILTER_INPUT_INT_INLINE\n";
            $rules .= "-A INPUT --in-interface $dev -d $mgmt_ip --protocol tcp --match tcp --dport 443 --jump ACCEPT\n";
            $rules .= "-A FORWARD --in-interface $dev --jump $FW_FILTER_FORWARD_INT_INLINE\n";

        # nothing? something is wrong
        } else {
            $logger->warn("Didn't assign any firewall rules to interface $dev.");
        }
    }

    # 'portal' interfaces handling
    foreach my $portal_interface ( @portal_ints ) {
        my $dev = $portal_interface->tag("int");
        $rules .= "-A INPUT --in-interface $dev -d 224.0.0.0/8 -j ACCEPT\n";
        $rules .= "-A INPUT --in-interface $dev -p vrrp -j ACCEPT\n";
        $rules .= "-A INPUT --in-interface $dev --jump $FW_FILTER_INPUT_PORTAL\n";
    }

    # 'radius' interfaces handling
    foreach my $radius_interface ( @radius_ints ) {
        my $dev = $radius_interface->tag("int");
        $rules .= "-A INPUT --in-interface $dev -d 224.0.0.0/8 -j ACCEPT\n";
        $rules .= "-A INPUT --in-interface $dev -p vrrp -j ACCEPT\n";
        $rules .= "-A INPUT --in-interface $dev --jump $FW_FILTER_INPUT_RADIUS\n";
    }

    # management interface handling
    if($management_network) {
        my $mgmt_int = $management_network->tag("int");
        $rules .= "-A INPUT --in-interface $mgmt_int --jump $FW_FILTER_INPUT_MGMT\n";
    }

    # high-availability interfaces handling
    foreach my $interface (map { $_->{Tint}} @ha_ints) {
        $rules .= "-A INPUT --in-interface $interface --jump $FW_FILTER_INPUT_INT_HA\n";
    }

    # Allow the NAT back inside through the forwarding table if inline is enabled
    if (is_inline_enforcement_enabled()) {
        my @values = split(',', get_inline_snat_interface());
        foreach my $val (@values) {
            foreach my $network ( keys %ConfigNetworks ) {
                next if ( !pf::config::is_network_type_inline($network) );
                my $inline_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
                my $nat = $ConfigNetworks{$network}{'nat_enabled'};
                if (defined ($nat) && (isdisabled($nat))) {
                    $rules .= "-A FORWARD -d $network/$inline_obj->{BITS} --in-interface $val ";
                    $rules .= "--jump ACCEPT";
                    $rules .= "\n";
                }
            }
            $rules .= "-A FORWARD --in-interface $val --match state --state ESTABLISHED,RELATED --jump ACCEPT\n";
        }
    }

    return $rules;
}


=item generate_inline_rules

Handling both FILTER and NAT tables at the same time.

=cut

sub generate_inline_rules {
    my ($self,$filter_rules_ref, $nat_prerouting_ref, $nat_postrouting_ref, $routed_postrouting_inline, $input_filtering_ref) = @_;
    my $logger = get_logger();

    $logger->info("Adding DNS DNAT rules for unregistered and isolated inline clients.");

    foreach my $network ( keys %ConfigNetworks ) {
        # We skip non-inline networks/interfaces
        next if ( !pf::config::is_network_type_inline($network) );
        # Set the correct gateway if it is an inline Layer 3 network
        my $gateway = $ConfigNetworks{$network}{'gateway'};
        if ( $ConfigNetworks{$network}{'type'} eq $pf::config::NET_TYPE_INLINE_L3 ) {
            foreach my $test_network ( keys %ConfigNetworks ) {
                my $net_addr = NetAddr::IP->new($test_network,$ConfigNetworks{$test_network}{'netmask'});
                my $ip = new NetAddr::IP::Lite clean_ip($ConfigNetworks{$network}{'next_hop'});
                if ($net_addr->contains($ip)) {
                    $gateway = $ConfigNetworks{$test_network}{'gateway'};
                }
            }
        }

        my $rule = "--protocol udp --destination-port 53 -s $network/$ConfigNetworks{$network}{'netmask'}";
        $$nat_prerouting_ref .= "-A $FW_PREROUTING_INT_INLINE $rule --match mark --mark 0x$IPTABLES_MARK_UNREG "
            . "--jump DNAT --to $gateway\n";
        $$nat_prerouting_ref .= "-A $FW_PREROUTING_INT_INLINE $rule --match mark --mark 0x$IPTABLES_MARK_ISOLATION "
            . "--jump DNAT --to $gateway\n";

        if (isenabled($ConfigNetworks{$network}{'split_network'}) && defined($ConfigNetworks{$network}{'reg_network'}) && $ConfigNetworks{$network}{'reg_network'} ne '') {
            $rule = "--protocol udp --destination-port 53 -s $ConfigNetworks{$network}{'reg_network'}";
            $$nat_prerouting_ref .= "-A $FW_PREROUTING_INT_INLINE $rule --match mark --mark 0x$IPTABLES_MARK_UNREG "
                . "--jump DNAT --to $gateway\n";
            $$nat_prerouting_ref .= "-A $FW_PREROUTING_INT_INLINE $rule --match mark --mark 0x$IPTABLES_MARK_ISOLATION "
                . "--jump DNAT --to $gateway\n";

        }

        if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
            $logger->info("Adding Proxy interception rules");
            foreach my $intercept_port ( split(',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
                my $rule = "--protocol tcp --destination-port $intercept_port -s $network/$ConfigNetworks{$network}{'netmask'}";
                $$nat_prerouting_ref .= "-A $FW_PREROUTING_INT_INLINE $rule --match mark --mark 0x$IPTABLES_MARK_UNREG "
                        . "--jump DNAT --to $gateway\n";
                $$nat_prerouting_ref .= "-A $FW_PREROUTING_INT_INLINE $rule --match mark --mark 0x$IPTABLES_MARK_ISOLATION "
                        . "--jump DNAT --to $gateway\n";
            }
        }
    }

    if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
        $logger->info("Adding Proxy interception rules");
        foreach my $intercept_port ( split(',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
            $$input_filtering_ref .= "-A $FW_FILTER_INPUT_INT_INLINE --protocol tcp --match tcp --dport $intercept_port "
                    . " --match mark --mark 0x$IPTABLES_MARK_UNREG  --jump ACCEPT\n";
            $$input_filtering_ref .= "-A $FW_FILTER_INPUT_INT_INLINE --protocol tcp --match tcp --dport $intercept_port "
                    . " --match mark --mark 0x$IPTABLES_MARK_UNREG  --jump ACCEPT\n";
            $$input_filtering_ref .= "-A $FW_FILTER_INPUT_INT_INLINE --protocol tcp --match tcp --dport $intercept_port "
                    . " --match mark --mark 0x$IPTABLES_MARK_REG  --jump DROP\n";
        }
    }


    $logger->info("Adding NAT Masquarade statement (PAT)");
    $$nat_postrouting_ref .= "-A $FW_POSTROUTING_INT_INLINE --jump MASQUERADE\n";

    $logger->info("Addind ROUTED statement");
    $$routed_postrouting_inline .= "-A $FW_POSTROUTING_INT_INLINE_ROUTED --jump ACCEPT\n";

    $logger->info("building firewall to accept registered users through inline interface");
    my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));

    if ($passthrough_enabled) {
        $$filter_rules_ref .= "-A $FW_FILTER_FORWARD_INT_INLINE --match mark --mark 0x$IPTABLES_MARK_UNREG -m set --match-set pfsession_passthrough dst,dst --jump ACCEPT\n";
        $$filter_rules_ref .= "-A $FW_FILTER_FORWARD_INT_INLINE --match mark --mark 0x$IPTABLES_MARK_ISOLATION -m set --match-set pfsession_isol_passthrough dst,dst --jump ACCEPT\n";
    }


    $$filter_rules_ref .= "-A $FW_FILTER_FORWARD_INT_INLINE --match mark --mark 0x$IPTABLES_MARK_REG --jump ACCEPT\n";
    }

=item generate_passthrough_rules

Creating the proper firewall rules to allow Google/Facebook OAuth2 and passthrough domain

=cut

sub generate_passthrough_rules {
    my ($passthrough,$forward_rules_ref,$nat_rules_ref,$forward_isol_rules_ref) = @_;
    my $logger = get_logger();

    $logger->info("Adding Forward rules to allow connections to the OAuth2 Providers and passthrough.");
    my $reg_int = "";

    if ($passthrough) {
        $$forward_rules_ref .= "-A $FW_FILTER_FORWARD_INT_VLAN -m set --match-set pfsession_passthrough dst,dst --jump ACCEPT\n";
        $$forward_rules_ref .= "-A $FW_FILTER_FORWARD_INT_VLAN -m set --match-set pfsession_passthrough src,src --jump ACCEPT\n";
        $$forward_isol_rules_ref .= "-A $FW_FILTER_FORWARD_INT_ISOL_VLAN -m set --match-set pfsession_isol_passthrough dst,dst --jump ACCEPT\n";
        $$forward_isol_rules_ref .= "-A $FW_FILTER_FORWARD_INT_ISOL_VLAN -m set --match-set pfsession_isol_passthrough src,src --jump ACCEPT\n";
    }

    # add passthroughs required by the provisionings
    generate_provisioning_passthroughs();

    $logger->info("Adding NAT Masquerade statement.");
    my $mgmt_int = $management_network->tag("int");
    my $SNAT_ip;
    if (defined($management_network->{'Tip'}) && $management_network->{'Tip'} ne '') {
        if (defined($management_network->{'Tvip'}) && $management_network->{'Tvip'} ne '') {
            $SNAT_ip = $management_network->{'Tvip'};
        } else {
            $SNAT_ip = $management_network->{'Tip'};
       }
    }

    foreach my $network ( keys %ConfigNetworks ) {
        my $network_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
        if ( pf::config::is_network_type_inline($network) ) {
            my $nat = $ConfigNetworks{$network}{'nat_enabled'};
            if (defined ($nat) && (isenabled($nat))) {
                $$nat_rules_ref .= "-A POSTROUTING -s $network/$network_obj->{BITS} -o $mgmt_int -j SNAT --to $SNAT_ip\n";
            }
        } else {
            $$nat_rules_ref .= "-A POSTROUTING -s $network/$network_obj->{BITS} -o $mgmt_int -j SNAT --to $SNAT_ip\n";
        }
    }

    # Enable nat if we defined another interface to route to internet
    my @ints = split(',', get_network_snat_interface());
    foreach my $int (@ints) {
        my $if   = IO::Interface::Simple->new($int);
        foreach my $network ( keys %ConfigNetworks ) {
            my $network_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
            if ( pf::config::is_network_type_inline($network) ) {
                my $nat = $ConfigNetworks{$network}{'nat_enabled'};
                if (defined ($nat) && (isenabled($nat))) {
                    $$nat_rules_ref .= "-A POSTROUTING -s $network/$network_obj->{BITS} -o $int -j SNAT --to ".$if->address."\n";
                }
            } else {
                $$nat_rules_ref .= "-A POSTROUTING -s $network/$network_obj->{BITS} -o $mgmt_int -j SNAT --to ".$if->address."\n";
            }
        }
    }
}

=item generate_inline_if_src_to_chain

Creating proper source interface matches to jump to the right chains for inline enforcement method.

=cut

sub generate_inline_if_src_to_chain {
    my ($self, $table) = @_;
    my $logger = get_logger();
    my $rules = '';

    # internal interfaces handling
    foreach my $interface (@internal_nets) {
        my $dev = $interface->tag("int");
        my $enforcement_type = $Config{"interface $dev"}{'enforcement'};

        # inline enforcement
        if (is_type_inline($enforcement_type)) {
            # send everything from inline interfaces to the inline chain
            $rules .= "-A PREROUTING --in-interface $dev --jump $FW_PREROUTING_INT_INLINE\n";
            $rules .= "-A POSTROUTING --out-interface $dev --jump $FW_POSTROUTING_INT_INLINE\n";
        }
    }

    # POSTROUTING
    if ( $table ne $FW_TABLE_NAT ) {
        my @values = split(',', get_inline_snat_interface());
        foreach my $val (@values) {
           $rules .= "-A POSTROUTING --out-interface $val ";
           $rules .= "--jump $FW_POSTROUTING_INT_INLINE";
           $rules .= "\n";
        }
    }

    # NAT POSTROUTING
    if ($table eq $FW_TABLE_NAT) {
        my $mgmt_int = $management_network->tag("int");

        # Every marked packet should be NATed
        # Note that here we don't wonder if they should be allowed or not. This is a filtering step done in FORWARD.
        foreach ($IPTABLES_MARK_UNREG, $IPTABLES_MARK_REG, $IPTABLES_MARK_ISOLATION) {
            my @values = split(',', get_inline_snat_interface());
            foreach my $val (@values) {
                foreach my $network ( keys %ConfigNetworks ) {
                    next if ( !pf::config::is_network_type_inline($network) );
                    my $inline_obj = new Net::Netmask( $network, $ConfigNetworks{$network}{'netmask'} );
                    my $nat = $ConfigNetworks{$network}{'nat_enabled'};
                    if (defined ($nat) && (isdisabled($nat))) {
                        $rules .= "-A POSTROUTING -s $network/$inline_obj->{BITS} --out-interface $val ";
                        $rules .= "--match mark --mark 0x$_ ";
                        $rules .= "--jump $FW_POSTROUTING_INT_INLINE_ROUTED";
                        $rules .= "\n";
                    }

                }

                $rules .= "-A POSTROUTING --out-interface $val ";
                $rules .= "--match mark --mark 0x$_ ";
                $rules .= "--jump $FW_POSTROUTING_INT_INLINE";
                $rules .= "\n";
            }
        }
    }

    return $rules;
}

=item generate_nat_redirect_rules

=cut

sub generate_nat_redirect_rules {
    my ($self) = @_;
    my $logger = get_logger();
    my $rules = '';

    # Exclude the OAuth from the DNAT
    my $passthrough_enabled = (isenabled($Config{'fencing'}{'passthrough'}) || isenabled($Config{'fencing'}{'isolation_passthrough'}));

    if ($passthrough_enabled) {
         $rules .= "-A $FW_PREROUTING_INT_INLINE -m set --match-set pfsession_passthrough dst,dst ".
               "--match mark --mark 0x$IPTABLES_MARK_UNREG --jump ACCEPT\n";
         $rules .= "-A $FW_PREROUTING_INT_INLINE -m set --match-set pfsession_isol_passthrough dst,dst ".
               "--match mark --mark 0x$IPTABLES_MARK_ISOLATION --jump ACCEPT\n";
    }

    # Now, do your magic
    foreach my $redirectport ( split( /\s*,\s*/, $Config{'inline'}{'ports_redirect'} ) ) {
        my ( $port, $protocol ) = split( "/", $redirectport );

        foreach my $network ( keys %ConfigNetworks ) {
            # We skip non-inline networks/interfaces
            next if ( !pf::config::is_network_type_inline($network) );
            # Set the correct gateway if it is an inline Layer 3 network
            my $gateway = $ConfigNetworks{$network}{'gateway'};
            if ( $ConfigNetworks{$network}{'type'} eq $pf::config::NET_TYPE_INLINE_L3 ) {
                foreach my $test_network ( keys %ConfigNetworks ) {
                    my $net_addr = NetAddr::IP->new($test_network,$ConfigNetworks{$test_network}{'netmask'});
                    my $ip = new NetAddr::IP::Lite clean_ip($ConfigNetworks{$network}{'next_hop'});
                    if ($net_addr->contains($ip)) {
                        $gateway = $ConfigNetworks{$test_network}{'gateway'};
                    }
                }
            }

            # Destination NAT to the portal on the ISOLATION mark
            $rules .=
                "-A $FW_PREROUTING_INT_INLINE --protocol $protocol --destination-port $port -s $network/$ConfigNetworks{$network}{'netmask'} " .
                "--match mark --mark 0x$IPTABLES_MARK_ISOLATION --jump DNAT --to $gateway\n";
        }

    }
    return $rules;
}

=item update_mark

This sub lives under the guarantee that there is a change, that if old_mark == new_mark it won't be called

=cut

# TODO wrap this into the commit transaction system of IPTables::Interface
# TODO once updated, we should re-validate that the marks are ok and re-try otherwise (maybe in a loop)
sub update_mark {
    my ($self , $mac, $old_mark, $new_mark) = @_;

    $self->iptables_unmark_node($mac, $old_mark);
    $self->iptables_mark_node($mac, $new_mark);
    return 1;
}

sub iptables_save {
    my ($self, $save_file) = @_;
    my $logger = get_logger();
    $logger->info( "saving existing iptables to " . $save_file );
    pf_run("/sbin/iptables-save -t nat > $save_file");
    pf_run("/sbin/iptables-save -t mangle >> $save_file");
    pf_run("/sbin/iptables-save -t filter >> $save_file");
}

sub iptables_restore {
    my ($self, $restore_file) = @_;
    my $logger = get_logger();
    if ( -r $restore_file ) {
        $logger->info( "restoring iptables from " . $restore_file );
        pf_run("/sbin/iptables-restore < $restore_file");
    }
}

sub iptables_restore_noflush {
    my ($self, $restore_file) = @_;
    my $logger = get_logger();
    if ( -r $restore_file ) {
        $logger->info(
            "restoring iptables (no flush) from " . $restore_file );
        pf_run("/sbin/iptables-restore -n < $restore_file");
    }
}

=back

=head1 NOT REIMPLEMENTED

These were features of the previous arp | dhcp modes that were not re-implemented for the reintroduction
of the inline mode because of time constraints.

=over

=item update_node

Update session when the ip address change

=cut

sub update_node {
    #Just to have an iptables method
}

=item get_inline_snat_interface

Return the list of network interface to enable SNAT.

=cut

sub get_inline_snat_interface {
    my ($self) = @_;
    my $logger = get_logger();
    if (defined ($Config{'inline'}{'interfaceSNAT'}) && $Config{'inline'}{'interfaceSNAT'} ne '') {
        return $Config{'inline'}{'interfaceSNAT'};
    } else {
        return  $management_network->tag("int");
    }
}

=item get_network_snat_interface

Return the list of network interface to enable SNAT for passthrough.

=cut

sub get_network_snat_interface {
    my ($self) = @_;
    my $logger = get_logger();
    if (defined ($Config{'network'}{'interfaceSNAT'}) && $Config{'network'}{'interfaceSNAT'} ne '') {
        return $Config{'network'}{'interfaceSNAT'};
    }
}

=item generate_interception_rules

Creating porper source interface matches to jump to the right chains for vlan enforcement method.

=cut

sub generate_interception_rules {
    my ($self, $nat_if_src_to_chain,$nat_prerouting_vlan, $input_inter_vlan_if) = @_;
    my $logger = get_logger();

    # internal interfaces handling
    foreach my $interface (@internal_nets) {
        my $dev = $interface->tag("int");
        my $enforcement_type = $Config{"interface $dev"}{'enforcement'};
        my $net_addr = NetAddr::IP->new($Config{"interface $dev"}{'ip'},$Config{"interface $dev"}{'mask'});
        # vlan enforcement
        if ($enforcement_type eq $IF_ENFORCEMENT_VLAN) {
            # send everything from vlan interfaces to the vlan chain
            $$nat_if_src_to_chain .= "-A PREROUTING --in-interface $dev --jump $FW_PREROUTING_INT_VLAN\n";
            foreach my $network ( keys %ConfigNetworks ) {
                next if (pf::config::is_network_type_inline($network));
                my %net = %{$ConfigNetworks{$network}};
                my $ip;
                if (defined($net{'next_hop'})) {
                    $ip = new NetAddr::IP::Lite clean_ip($net{'next_hop'});
                } else {
                    $ip = new NetAddr::IP::Lite clean_ip($net{'gateway'});
                }
                if ($net_addr->contains($ip)) {
                    my $destination = $Config{"interface $dev"}{'vip'} || $Config{"interface $dev"}{'ip'};
                    if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
                        foreach my $intercept_port ( split( ',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
                            my $rule = "--protocol tcp --destination-port $intercept_port -s $network/$ConfigNetworks{$network}{'netmask'}";
                            $$nat_prerouting_vlan .= "-A $FW_PREROUTING_INT_VLAN $rule --jump DNAT --to $destination\n";
                        }
                    }
                    my $rule = "--protocol udp --destination-port 53 -s $network/$ConfigNetworks{$network}{'netmask'}";
                    $$nat_prerouting_vlan .= "-A $FW_PREROUTING_INT_VLAN $rule --jump DNAT --to $destination\n";
                    $rule = "--protocol tcp --destination-port 53 -s $network/$ConfigNetworks{$network}{'netmask'}";
                    $$nat_prerouting_vlan .= "-A $FW_PREROUTING_INT_VLAN $rule --jump DNAT --to $destination\n";
                }
            }
        }
    }
    if (defined($Config{'fencing'}{'interception_proxy_port'}) && isenabled($Config{'fencing'}{'interception_proxy'})) {
        foreach my $intercept_port ( split( ',', $Config{'fencing'}{'interception_proxy_port'} ) ) {
            my $rule = "--protocol tcp --destination-port $intercept_port";
            $$input_inter_vlan_if .= "-A $FW_FILTER_INPUT_INT_VLAN $rule --jump ACCEPT\n";
        }
    }
}

sub generate_provisioning_passthroughs {
    my $logger = get_logger();
    $logger->debug("Installing passthroughs for provisioning");
    foreach my $config (tied(%ConfigProvisioning)->search(type => 'sepm')) {
        $logger->info("Adding passthrough for Symantec Endpoint Manager");
        my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{'host'},8014 2>&1");
        my @lines  = pf_run($cmd);
    }

    foreach my $config (tied(%ConfigProvisioning)->search(type => 'mobileiron')) {
        $logger->info("Adding passthrough for MobileIron");
        # Allow the host for the onboarding of devices
        my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{boarding_host},$config->{boarding_port} 2>&1");
        my @lines  = pf_run($cmd);
        # Allow http communication with the MobileIron server
        $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{boarding_host},$HTTP_PORT 2>&1");
        @lines  = pf_run($cmd);
        # Allow https communication with the MobileIron server
        $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{boarding_host},$HTTPS_PORT 2>&1");
        @lines  = pf_run($cmd);
    }

    foreach my $config (tied(%ConfigProvisioning)->search(type => 'opswat')) {
        $logger->info("Adding passthrough for OPSWAT");
        # Allow http communication with the OSPWAT server
        my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTP_PORT 2>&1");
        my @lines  = pf_run($cmd);
        # Allow https communication with the OPSWAT server
        $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTPS_PORT 2>&1");
        @lines  = pf_run($cmd);
    }

    foreach my $config (tied(%ConfigProvisioning)->search(type => 'sentinelone')) {
        $logger->info("Adding passthrough for SentinelOne");
        # Allow http communication with the SentinelOne server
        my $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTP_PORT 2>&1");
        my @lines  = pf_run($cmd);
        # Allow https communication with the SentinelOne server
        $cmd = untaint_chain("sudo ipset --add pfsession_passthrough $config->{host},$HTTPS_PORT 2>&1");
        @lines  = pf_run($cmd);
    }


}

sub generate_domain_rules {
    my ( $filter_forward_domain, $domain_postrouting ) = @_;
    my $logger = get_logger();
    foreach my $name (@{pf::ConfigStore::Domain->new->readAllIds}){
        $$filter_forward_domain .= "-A FORWARD -o $name-b -j ACCEPT\n";
        $$filter_forward_domain .= "-A FORWARD -i $name-b -j ACCEPT\n";
    }

    # MOVE ME TO SOMEWHERE - BUT WHERE ????? - ANYWHERE IS BETTER THAN THIS !
    my $domain_network = "169.254.0.0/16";

    my $mgmt_ip = (defined($management_network->tag('vip'))) ? $management_network->tag('vip') : $management_network->tag('ip');
    my $mgmt_int = $management_network->tag('int');
    $$domain_postrouting .= "-A POSTROUTING -s $domain_network -o $mgmt_int -j SNAT --to-source $mgmt_ip \n"
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
USA.

=cut

1;
