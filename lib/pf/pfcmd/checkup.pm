package pf::pfcmd::checkup;

=head1 NAME

pf::pfcmd::checkup - pfcmd's checkup tasks

=head1 DESCRIPTION

This modules holds all the tests performed by 'pfcmd checkup' which is a general configuration sanity test.

=cut

use strict;
use warnings;

use Fcntl ':mode'; # symbolic file permissions
use Try::Tiny;
use Readonly;

use pf::constants::filters;
use pf::validation::profile_filters;
use pf::constants;
use pf::constants::config qw($TIME_MODIFIER_RE);
use pf::config qw(
    %Config
    $management_network
    $IF_INTERNAL
    $IF_ENFORCEMENT_VLAN
    $IF_ENFORCEMENT_INLINE
    %ConfigNetworks
    $monitor_int
    %ConfigAuthentication
    %ConfigNetworks
    @internal_nets
    %Doc_Config
    $INLINE_API_LEVEL
    $ROLE_API_LEVEL
    $RADIUS_API_LEVEL
    $ROLES_API_LEVEL
    %Profiles_Config
    %ConfigBillingTiers
    $SELFREG_MODE_EMAIL
    $SELFREG_MODE_SMS
    $SELFREG_MODE_SPONSOR
    is_inline_enforcement_enabled
);
use pf::security_event_config;
use pf::util;
use pf::config::util;
use pf::services;
use pf::authentication;
use NetAddr::IP;
use pf::web::filter;
use pfconfig::manager;
use pfconfig::namespaces::config::Pf;
use pfconfig::namespaces::resource::clusters_hostname_map;
use pf::version;
use File::Slurp;
use pf::file_paths qw(
    $conf_dir
    $lib_dir
    $install_dir
    $network_config_file
    $bin_dir
    $sbin_dir
    $log_dir
    @log_files
    $generated_conf_dir
    $pfdetect_config_file
);
use Crypt::OpenSSL::X509;
use Date::Parse;
use pf::factory::condition::profile;
use pf::condition_parser qw(parse_condition_string);
use pf::cluster;
use pf::config::builder::pfdetect;
use pf::config::builder::scoped_filter_engines;
use pf::IniFiles;

use lib $conf_dir;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        sanity_check
    );
}

# Error levels
Readonly our $FATAL => "FATAL";
Readonly our $WARN => "WARNING";

# Pieces
Readonly our $SEVERITY => "severity";
Readonly our $MESSAGE => "message";

our @problems;

=head1 SUBROUTINES

=over

=item add_problem

Add a problem to the problem list.

add_problem( severity, message );

=cut

sub add_problem {
    my ($severity, $message) = @_;

    push @problems, {
        $SEVERITY => $severity,
        $MESSAGE => $message
    };
}

=item sanity_check

Returns an array of hashes of the form ( $SEVERITY => ... , $MESSAGE => ... )

=cut

sub sanity_check {
    my (@services) = @_;

    # emptying problem list
    @problems = ();
    print "Checking configuration sanity...\n";

    # SELinux test only for RedHat based distros
    if ( -e "/etc/redhat-release" && `getenforce` =~ /^Enforcing/ ) {
        add_problem( $WARN,
            'SELinux is in enforcing mode. This is currently not supported in PacketFence'
        );
    }

    service_exists(@services);
    interfaces_defined();
    interfaces();

    if ( isenabled($Config{'services'}{'radiusd'} ) ) {
        freeradius();
    }

    billing();

    database();
    authentication();
    network();
    fingerbank();
    inline() if (is_inline_enforcement_enabled());
    apache();
    web_admin();
    registration();
    is_config_documented();
    extensions();
    permissions();
    security_events();
    switches();
    connection_profiles();
    guests();
    vlan_filter_rules();
    apache_filter_rules();
    db_check_version();
    valid_certs();
    portal_modules();
    cluster();
    provisioning();
    scan();
    pfdetect();
    validate_access_filters();

    return @problems;
}

sub service_exists {
    my (@services) = @_;

    foreach my $service (@services) {
        next if ($service eq 'pf');
        my $exe = ( $Config{'services'}{"${service}_binary"} || "$install_dir/sbin/$service" );
        if ($service =~ /^(pfipset|pfsso|httpd\.dispatcher|api-frontend)$/) {
            $exe = "$sbin_dir/pfhttpd";
        } elsif ($service =~ /httpd\.(.*)/) {
            $exe = ( $Config{'services'}{"httpd_binary"} || "$install_dir/sbin/$service" );
        } elsif ($service =~ /redis_(.*)/) {
            $exe = ( $Config{'services'}{"redis_binary"} || "$install_dir/sbin/$service" );
        }
        if ( !-e $exe ) {
            add_problem( $WARN, "$exe for $service does not exist !" );
        }
    }
}

=item interfaces_defined

check the config file to make sure interfaces are fully defined

=cut

sub interfaces_defined {

    my $nb_management_interface = 0;

    # TODO - change me ?
    my $cached_pf_config = pfconfig::namespaces::config::Pf->new(pfconfig::manager->new);
    $cached_pf_config->build();
    foreach my $interface ( $cached_pf_config->GroupMembers("interface") ) {
        my %int_conf = %{$Config{$interface}};
        my $int_with_no_config_required_regexp = qr/(?:monitor|dhcplistener|dhcp-listener|high-availability)/;

        if (!defined($int_conf{'type'}) || $int_conf{'type'} !~ /$int_with_no_config_required_regexp/) {
            if (!defined $int_conf{'ip'} || !defined $int_conf{'mask'}) {
                add_problem( $FATAL, "incomplete network information for $interface" );
            }
        }

        my $int_types = qr/(?:internal|management|managed|monitor|dhcplistener|dhcp-listener|high-availability|portal|radius)/;
        if (defined($int_conf{'type'}) && $int_conf{'type'} !~ /$int_types/) {
            add_problem( $FATAL, "invalid network type $int_conf{'type'} for $interface" );
        }

        $nb_management_interface++ if (defined($int_conf{'type'}) && $int_conf{'type'} =~ /management|managed/);
    }

    if ($nb_management_interface != 1)  {
        add_problem( $FATAL, "please define exactly one management interface" );
    }
}

=item interfaces

check the Netmask objs and make sure a managed and internal interface exist

=cut

sub interfaces {

    if ( !scalar(get_internal_devs()) ) {
        add_problem( $WARN, "internal network(s) not defined!" );
    }

    my %seen;
    my @network_interfaces;
    push @network_interfaces, get_internal_devs();
    push @network_interfaces, $management_network->tag("int") if ($management_network);
    foreach my $interface (@network_interfaces) {
        my $device = "interface " . $interface;

        if ( !($Config{$device}{'mask'} && $Config{$device}{'ip'} && $Config{$device}{'type'}) && !$seen{$interface}) {
            add_problem( $FATAL,
                "Incomplete network information for $device. " .
                "IP, network mask and type required."
            );
        }
        $seen{$interface} = 1;

        foreach my $type ( split( /\s*,\s*/, $Config{$device}{'type'} ) ) {
            if ($type eq $IF_INTERNAL && !defined($Config{$device}{'enforcement'})) {
                add_problem( $FATAL,
                    "Incomplete network information for $device. " .
                    "Enforcement technique must be defined on an internal interface. " .
                    "Your choices are: $IF_ENFORCEMENT_VLAN or $IF_ENFORCEMENT_INLINE. " .
                    "If unsure refer to the documentation."
                );
            }

            if ($type eq 'managed') {
                add_problem( $WARN,
                    "Interface type 'managed' is deprecated and will be removed in future versions of PacketFence. " .
                    "You should use the 'management' keyword instead. " .
                    "Seen on interface $interface."
                );
            }
        }
        my $ip = new NetAddr::IP::Lite clean_ip($Config{$device}{'ip'});
        if (defined($Config{$device}{'enforcement'}) && ($Config{$device}{'enforcement'} eq $IF_ENFORCEMENT_INLINE)) {
            foreach my $network (keys %ConfigNetworks) {
                my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
                if ($net_addr->contains($ip)) {
                    if ($Config{$device}{'enforcement'} ne $ConfigNetworks{$network}{'type'}) {
                        add_problem( $WARN,
                            "You defined an inline interface ($Config{$device}{'ip'}) but no inline network"
                        );
                    }
                }
            }
        }
    }
}


=item freeradius

Validation related to the FreeRADIUS daemon

=cut

sub freeradius {

    if ( !-x $Config{'services'}{'radiusd_binary'} ) {
        add_problem( $FATAL, "radiusd binary is not executable / does not exist!" );
    }
}

=item fingerbank

Validation to make sure Fingerbank outside lib symlink is present

=cut

sub fingerbank {
    if ( !-l '/usr/local/pf/lib/fingerbank' ) {
        add_problem( $WARN, "Fingerbank symlink does not exists" );
    }
}


sub authentication {
    authentication_unique_sources();
    authentication_rules_classes();
}

sub authentication_unique_sources {
    foreach my $authentication_source ( @pf::authentication::authentication_sources ) {
        if ( $authentication_source->unique ) {
            my $count = @{pf::authentication::getAuthenticationSourcesByType($authentication_source->type)};
            if ( $count > 1 ) {
                add_problem( $FATAL, "Tried to use an authentication source '" . $authentication_source->id . "' of type '" . $authentication_source->type . "' while this type being unique and an authentication source of this type already exists" );
            }
        }
    }
}

sub authentication_rules_classes {
    foreach my $authentication_source_id ( keys %ConfigAuthentication ) {
        if( $authentication_source_id =~ /\./ ) {
            add_problem( $WARN, "The id of a source cannot contain a space or a dot '$authentication_source_id'");
        }
        next if !$ConfigAuthentication{$authentication_source_id}{'rules'};

        my $authentication_source = $ConfigAuthentication{$authentication_source_id};
        my $rules = $authentication_source->{'rules'};
        foreach my $rule_id ( keys %$rules ) {
            my $rule = $authentication_source->{'rules'}->{$rule_id};

            # Check if rule class is configured
            add_problem( $WARN, "Rule '$rule_id' does not have any configured class. Defaulting to 'authentication'" ) if !$rule->{'class'};
            next if !$rule->{'class'};

            # Check if rule class is allowed on this type of authentication source
            my $authenticationSourceObject = pf::authentication::getAuthenticationSource($authentication_source_id);
            my %available_rule_classes =  map { $_ => 1 } @{ $authenticationSourceObject->available_rule_classes };
            add_problem( $WARN, "Rule class '" . $rule->{'class'} . "' is not allowed on a '" . $authentication_source->{'type'} . "' source type. It will be ignored." ) if !exists($available_rule_classes{$rule->{'class'}});

            # Check if configured rule action(s) is/are allowed based on the configured class
            my $actions = $rule->{'actions'};
            my %allowed_actions = map { $_ => 1 } @{ $Actions::ACTIONS{$rule->{'class'}} };
            foreach my $action_id ( keys %$actions ) {
                my $action = $rule->{'actions'}->{$action_id};
                $action = substr($action, 0, index($action, '='));
                add_problem( $WARN, "Action '$action_id' of rule '$rule_id' is not part of the '" . $rule->{'class'} . "' rule class allowed actions. It will be ignored." ) if !exists($allowed_actions{$action});
            }
        }
    }
}

=item network

Configuration validation of the network portion of the config

=cut

sub network {

    # check that networks.conf is not empty when services.pfdhcp
    # is enabled
    if (isenabled($Config{'services'}{'pfdhcp'}) && ((!-e $network_config_file ) || (-z $network_config_file ))){
        add_problem( $WARN, "networks.conf is empty but services.dhcpd is enabled. Disable it to remove this warning." );
    }

    foreach my $network (keys %ConfigNetworks) {
        # shorter, more convenient accessor
        my %net = %{$ConfigNetworks{$network}};

        # isolation / registration deprecation (now vlan-isolation and vlan-registration)
        # TODO once isolation / registration deprecated use pf::config::get_network_type($network), test for undef
        # and upgrade to $FATAL
        if (defined($net{'type'}) && $net{'type'} =~ /^isolation$|^registration$/i) {
            add_problem( $WARN,
                "networks.conf type isolation or registration is deprecated in favor of " .
                "vlan-isolation and vlan-registration. " .
                "Make sure to update your configuration as the old keywords will be removed in the future. " .
                "Network $network"
            );
        }

        # pf_gateway deprecated in favor of next_hop
        # TODO upgrade to FATAL once pf_gateway officially deprecated (somewhere in 2012)
        if (defined($net{'pf_gateway'}) && $net{'pf_gateway'} ne '') {
            add_problem( $WARN,
                "networks.conf pf_gateway is deprecated in favor of next_hop. " .
                "Make sure to update your configuration as the old parameters will be removed in the future. " .
                "Network $network"
            );
        }

        # validate dns entry if named is enabled
        if (exists $net{'named'} &&  $net{'named'} =~ /enabled/i) {
            for my $dns ( split( ",", $net{'dns'})) {
                if (!valid_ip($dns)) {
                    add_problem( $FATAL, "networks.conf: DNS IP is not valid for network $network" );
                }
            }
        }

        # mandatory fields if we run DHCP (should be most cases)
        if (exists $net{'dhcpd'} &&  $net{'dhcpd'} =~ /enabled/i) {
            my $netmask_valid = (defined($net{'netmask'}) && valid_ip($net{'netmask'}));
            my $gw_valid = (defined($net{'gateway'}) && valid_ip($net{'gateway'}));
            my $domainname_valid = (defined($net{'domain-name'}) && $net{'domain-name'} !~ /^\s*$/);
            my $range_valid = (
                defined($net{'dhcp_start'}) && $net{'dhcp_start'} !~ /^\s*$/ &&
                defined($net{'dhcp_end'}) && $net{'dhcp_end'} !~ /^\s*$/
            );
            my $default_lease_valid = (
                !defined($net{'dhcp_default_lease_time'}) || $net{'dhcp_default_lease_time'} =~ /^\d+$/
            );
            my $max_lease_valid = ( !defined($net{'dhcp_max_lease_time'}) || $net{'dhcp_max_lease_time'} =~ /^\d+$/ );
            if (!($netmask_valid && $gw_valid && $domainname_valid && $range_valid && $default_lease_valid && $max_lease_valid)) {
                add_problem( $WARN, "networks.conf: Incomplete DHCP information for network $network" );
            }
        }

        # run inline network tests
        network_inline($network) if (pf::config::is_network_type_inline($network));
    }
}


=item network_inline

Tests that validate the configuration of an inline network.

=cut

sub network_inline {
    my ($network) = @_;
    # shorter, more convenient accessor
    my %net = %{$ConfigNetworks{$network}};

    # inline interface with named=disabled is not what you want
    if ( $net{'named'} =~ /disabled/i ) {
        add_problem( $WARN,
                "networks.conf type inline with named disabled is *not* what you want. " .
                "Since we're DNATTING DNS if in an unreg or isolated state, you'll want to change that to enabled."
        );
    }

    # inline interfaces should have at least one local gateway
    my $found = 0;
    foreach my $int (@internal_nets) {
        my $net_addr = NetAddr::IP->new($Config{ 'interface ' . $int->tag('int') }{'ip'},$Config{ 'interface ' . $int->tag('int') }{'mask'});
        my $ip = new NetAddr::IP::Lite clean_ip($net{'next_hop'}) if defined($net{'next_hop'});
        if ( $Config{ 'interface ' . $int->tag('int') }{'ip'} eq $net{'gateway'} || (defined($Config{ 'interface ' . $int->tag('int') }{'vip'}) && $Config{ 'interface ' . $int->tag('int') }{'vip'} eq $net{'gateway'} ) || (defined($net{'next_hop'}) && $net_addr->contains($ip) ) ) {

            $found = 1;
            next;
        }
    }
    # That check is useless in a cluster because the gateway is returned automagically by pfdhcp
    if ( !$cluster_enabled && !$found ) {
        add_problem( $WARN,
            "networks.conf $network gateway ($net{'gateway'}) is not bound to an internal interface. " .
            "Assume your configuration is wrong unless you know what you are doing."
        );
    }
    my $net_addr = NetAddr::IP->new($network,$ConfigNetworks{$network}{'netmask'});
    foreach my $int (@internal_nets) {
        my $ip = new NetAddr::IP::Lite clean_ip($Config{ 'interface ' . $int->tag('int') }{'ip'});
        if ($net_addr->contains($ip)) {
            if ($Config{ 'interface ' . $int->tag('int') }{'enforcement'} ne $ConfigNetworks{$network}{'type'}) {
                add_problem( $WARN,
                    "You defined a inline network ($int) but no inline interface."
                );
            }
         next;
        }
    }
}

=item inline

If some interfaces are configured to run in inline enforcement then these tests will run

=cut

sub inline {

    my $result = pf_run("cat /proc/sys/net/ipv4/ip_forward");
    if ($result ne "1\n") {
        add_problem( $WARN,
            "inline mode needs ip_forward enabled to work properly. " .
            "Refer to the administration guide to enable ip_forward."
        );
    }
}

=item database

database check

=cut

sub database {

    try {

        # make sure pid "admin" and "default" exists
        require pf::person;
        if ( !pf::person::person_exist("admin") ) {
            add_problem( $FATAL, "person user id \"admin\" must exist - please reinitialize your database" );
        }
        if ( !pf::person::person_exist("default") ) {
            add_problem( $FATAL, "person user id \"default\" must exist - please reinitialize your database" );
        }

    } catch {
        if ($_ =~ /unable to connect to database/) {
            add_problem(
                $FATAL,
                "Unable to connect to your database. "
                . "Please verify your connection settings in conf/pf.conf and make sure that it is started."
            );
        } else {
            add_problem( $FATAL, "Unexpected database problem: $_" );
        }
    };

}

=item web_admin

Web Administration interface checks

=cut

sub web_admin {

    # make sure admin port exists
    if ( !$Config{'ports'}{'admin'} ) {
        add_problem( $WARN, "please set the web admin port in pf.conf (ports.admin)" );
    }

}

=item registration

Registration configuration sanity

=cut

sub registration {

}

# TODO Consider moving to a test
sub is_config_documented {
    # TODO - change me ?
    my $cached_pf_config = pfconfig::namespaces::config::Pf->new(pfconfig::manager->new);
    $cached_pf_config->build();
    if (!-e $conf_dir . '/pf.conf') {
        add_problem($WARN, 'We have been unable to load your configuration. Are you sure you ran configurator ?');
        return;
    }

    #starting with documentation vs configuration
    #i.e. make sure that pf.conf contains everything defined in
    #documentation.conf
    foreach my $section ( keys %Doc_Config) {
        next unless $section =~ /\./;
        my ( $group, $item ) = split( /\./, $section );
        my $doc = $Doc_Config{$section};
        my $type = $doc->{'type'};

        next if ( $section =~ /^(passthroughs)$/ || $group =~ /^(interface|services)$/ );
        next if ( ( $group eq 'alerting' ) && ( $item eq 'fromaddr' ) );
        next if ( ( $group eq 'provisioning' ) && ( $item eq 'certificate') );
        next if ( $item =~ /^temporary_/i );

        if ( !exists $Config{$group} || !exists $Config{$group}{$item} ) {
            add_problem( $WARN, "pf.conf value $group\.$item is not defined!" );
        } elsif (defined( $Config{$group}{$item} ) ) {
            if ( $type eq "time" ) {
                if ( $cached_pf_config->{_file_cfg}{$group}{$item} !~ /\d+$TIME_MODIFIER_RE$/ ) {
                    add_problem( $WARN,
                        "pf.conf value $group\.$item does not explicity define interval (eg. 7200s, 120m, 2h) " .
                        "- please define it before running packetfence"
                    );
                }
            } elsif ( $type eq "multi" || $type eq "toggle" ) {
                my @selectedOptions = split( /\s*,\s*/, $cached_pf_config->{_file_cfg}{$group}{$item} // '' );
                my @availableOptions = @{$doc->{'options'}};
                foreach my $currentSelectedOption (@selectedOptions) {
                    if ( grep(/^$currentSelectedOption$/, @availableOptions) == 0 ) {
                        add_problem( $WARN,
                            "pf.conf values for $group\.$item must be among the following: " .
                            join("|",@availableOptions) .  " but you used $currentSelectedOption. " .
                            "If you are sure of this choice, please update conf/documentation.conf"
                        );
                    }
                }
            }
            elsif ($type eq 'numeric') {
                if (exists $doc->{minimum}) {
                    my $minimum = $doc->{minimum};
                    add_problem( $WARN,"$section is less than the minimum value of $minimum" ) if $Config{$group}{$item} < $minimum;
                }
            }
        } elsif( $Config{$group}{$item} ne "0"  ) {
            add_problem( $WARN, "pf.conf value $group\.$item is not defined!" );
        }
    }

    #and now the opposite way around
    #i.e. make sure that pf.conf does not contain more
    #than what is documented in documentation.conf
    foreach my $section (keys %Config) {
        next if (  ($section eq "passthroughs") || ($section eq "")
                  || ($section =~ /^(services|interface|nessus_category_policy|nessus_scan_by_fingerprint)/));

        foreach my $item  (keys %{$Config{$section}}) {
            next if ( $item =~ /^temporary_/i );
            if ( !defined( $Doc_Config{"$section.$item"} ) ) {
                add_problem( $WARN,
                    "unknown configuration parameter $section.$item ".
                    "if you added the parameter yourself make sure it is present in conf/documentation.conf"
                );
            }
        }
    }

}

=item extensions

Performs version checking of the extension points.

=cut

sub extensions {

    my @extensions = (
        { 'name' => 'Inline', 'module' => 'pf::inline::custom', 'api' => $INLINE_API_LEVEL, },
        { 'name' => 'Role', 'module' => 'pf::role::custom', 'api' => $ROLE_API_LEVEL, },
        { 'name' => 'RADIUS', 'module' => 'pf::radius::custom', 'api' => $RADIUS_API_LEVEL, },
        { 'name' => 'Roles', 'module' => 'pf::roles::custom', 'api' => $ROLES_API_LEVEL, },
    );

    foreach my $extension_ref ( @extensions ) {

        try {
            # try loading it
            eval "require $extension_ref->{module}";
            # throw exceptions
            die($@) if ($@);

            if (!defined($extension_ref->{module}->VERSION())) {
                add_problem($WARN,
                    "$extension_ref->{name} extension point ($extension_ref->{module}) VERSION is not defined."
                );
            }
            elsif ($extension_ref->{api} > $extension_ref->{module}->VERSION()) {
                add_problem( $WARN,
                    "$extension_ref->{name} extension point ($extension_ref->{module}) is not at the correct API level. " .
                    "Did you read the UPGRADE document?"
                );
            }
        }
        catch {
            chomp($_);
            add_problem($WARN, "Uncaught exception while trying to identify $extension_ref->{name} extension version: $_");
        };
    }
}

=item permissions

Checking some important permissions

=cut

sub permissions {

    my (undef, undef, $pfcmd_mode, undef, $pfcmd_owner, $pfcmd_group) = stat($bin_dir . "/pfcmd");
    # pfcmd needs to be owned by root (owner id 0 / group id 0)
    if ($pfcmd_owner || $pfcmd_group) {
        add_problem( $FATAL, "pfcmd needs to be owned by root. Fix with chown root:root $bin_dir/pfcmd" );
    }
    # and pfcmd needs to be setuid / setgid
    if (!($pfcmd_mode & S_ISUID && $pfcmd_mode & S_ISGID)) {
        add_problem( $FATAL, "pfcmd needs setuid and setgid bit set to run properly. Fix with chmod ug+s $bin_dir/pfcmd" );
    }

    # log owner must be pf otherwise apache or pf daemons won't start
    foreach my $log_file (@log_files) {
        # if log doesn't exist it is created correctly so no need to complain
        next if (!-f $log_dir . '/' . $log_file);

        add_problem( $FATAL, "$log_file must be owned by user pf. Fix with chown pf -R $log_dir/" )
            unless (getpwuid((stat($log_dir . '/' . $log_file))[4]) eq 'pf');
    }
}

=item apache

Apache related tests

=cut

sub apache {

    # we dynamically adjust apache's configuration based on total system memory
    # we will first here test if we can figure it out
    my $total_ram = get_total_system_memory();
    if (!defined($total_ram)) {
        add_problem(
            $WARN,
            "Unable to find out how much system memory is available. "
            . "We'll assume you have 2 Gigabyte. "
            . "Please report an issue."
        );
    }

    # Apache PerlPostConfigRequire scripts *must* compile otherwise apache startup silently fails
    my $captive_portal = pf_run("perl -c $lib_dir/pf/web/captiveportal_modperl_require.pl 2>&1");
    if (!defined($captive_portal) || $captive_portal !~ /syntax OK$/) {
        add_problem(
            $FATAL, "Apache will fail to start! $lib_dir/pf/web/captiveportal_modperl_require.pl doesn't compile"
        );
    }
    my $back_end = pf_run("perl -c $lib_dir/pf/web/backend_modperl_require.pl 2>&1");
    if (!defined($back_end) || $back_end !~ /syntax OK$/) {
        add_problem(
            $FATAL, "Apache will fail to start! $lib_dir/pf/web/backend_modperl_require.pl doesn't compile"
        );
    }
}

=item security_events

Checking for security_events configurations

=cut

sub security_events {
    require pfconfig::namespaces::FilterEngine::SecurityEvent;
    require pf::security_event_config;
    require List::MoreUtils;

    # Check for deprecated actions and attributes
    my @deprecated_actions = qw(trap email popup);
    my @deprecated_attr = qw(whitelisted_categories);
    while(my ($vid, $config) = each %pf::security_event_config::SecurityEvent_Config ){
        foreach my $attr (@deprecated_attr){
            if(exists $config->{$attr}){
                add_problem($WARN, "SecurityEvent attribute $attr is deprecated in security_event $vid. Please adjust your configuration according to the upgrade guide.");
            }
        }

        my @actions = split(/\s*,\s*/, $config->{actions});
        foreach my $action (@deprecated_actions){
            if(List::MoreUtils::any {$_ eq $action} @actions){
                add_problem($WARN, "SecurityEvent action $action is deprecated in security_event $vid. Please adjust your configuration according to the upgrade guide.");
            }
        }
    }

    my $engine = pfconfig::namespaces::FilterEngine::SecurityEvent->new;
    $engine->build();
    while (my ($security_event, $triggers) = each %{$engine->{invalid_triggers}}) {
        foreach my $trigger (@$triggers){
            add_problem($WARN, "Invalid trigger $trigger for security_event $security_event");
        }
    }
}

=item switches

Checking for switches configurations

=cut

sub switches {
    require pf::ConfigStore::Switch;
    my $configStore = pf::ConfigStore::Switch->new;
    my %switches_conf;

    my @errors = @Config::IniFiles::errors;
    if ( scalar(@errors) ) {
        add_problem( $FATAL, "switches.conf | Error reading switches.conf" );
    }
    my $cachedConfig = $configStore->cachedConfig;
    $cachedConfig->toHash(\%switches_conf);
    $cachedConfig->cleanupWhitespace(\%switches_conf);

    my $default_section = $switches_conf{default};
    foreach my $section ( keys %switches_conf ) {
        # skip default switch parameters
        next if ( $section =~ /^default$/i );
        my $is_group = $section =~ /^group/;
        my $data = $switches_conf{$section};
        my $group_section = {};
        if (exists $data->{group}) {
            my $group = "group $data->{group}";
            if (exists $switches_conf{$group}) {
                $group_section = $switches_conf{$group};
                add_problem( $WARN, "switches.conf | Switch $section has group parameter" ) if $is_group;
            } else {
                add_problem( $WARN, "switches.conf | Switch $section references a non existent group '$data->{group}'" );
            }
        }
        if ( $section eq '127.0.0.1' ) {
            add_problem( $WARN, "switches.conf | Switch 127.0.0.1 is defined but it had to be removed" );
        }
        my $type = _first_value('type', $data, $group_section, $default_section);
        my $mode = _first_value('mode', $data, $group_section, $default_section);
        # validate that switches are not duplicated (we check for type and mode specifically) fixes #766
        if ( ref($type) eq 'ARRAY' || ref($mode) eq 'ARRAY' ) {
            add_problem( $WARN, "switches.conf | Error around $section Did you define the same switch twice?" );
        }
        if ( (!defined $type) || $type eq '' ) {
            add_problem( $WARN, "switches.conf | Switch type for switch ($section) is not defined");
        } else {
            # check type
            $type = "pf::Switch::$type";
            $type = untaint_chain($type);
            if ( !(eval "$type->require()" ) ) {
                add_problem( $WARN, "switches.conf | Switch type ($type) is invalid for switch $section" );
            }
        }
        # check for valid switch ID
        unless ( $is_group || valid_mac_or_ip($section) || valid_ip_range($section) ) {
            add_problem( $WARN, "switches.conf | Switch IP is invalid for switch $section" );
        }
        next if $is_group;

        # check SNMP version
        my $SNMPVersion = ( $data->{'SNMPVersion'}
                || $data->{'version'}
                || $default_section->{'SNMPVersion'}
                || $default_section->{'version'}
                || $group_section->{'SNMPVersion'}
                || $group_section->{'version'} );
        if ( !defined($SNMPVersion) ) {
            add_problem( $WARN, "switches.conf | Switch SNMP version is missing for switch $section"
                    . "Please provide one specific to the switch or in default." );
        } elsif ( !($SNMPVersion =~ /^1|2c|3$/) ) {
            add_problem( $WARN, "switches.conf | Switch SNMP version ($SNMPVersion) is invalid for switch $section" );
        }

        # check SNMP Trap version
        my $SNMPVersionTrap = _first_value('SNMPVersionTrap', $data, $group_section, $default_section);
        if (!defined($SNMPVersionTrap)) {
            add_problem( $WARN, "switches.conf | Switch SNMP Trap version is missing for switch $section"
                    . "Please provide one specific to the switch or in default." );
        } elsif ( !( $SNMPVersionTrap =~ /^1|2c|3$/ ) ) {
            add_problem( $WARN, "switches.conf | Switch SNMP Trap version ($SNMPVersionTrap) is invalid "
                    . "for switch $section" );
        } elsif ( $SNMPVersionTrap =~ /^3$/ ) {
            # mandatory SNMPv3 traps parameters
            foreach (qw(
                SNMPUserNameTrap
                SNMPAuthProtocolTrap SNMPAuthPasswordTrap
                SNMPPrivProtocolTrap SNMPPrivPasswordTrap
            )) {
                add_problem( $WARN, "switches.conf | $_ is missing for switch $section" )
                    unless defined _first_value($_, $data, $group_section, $default_section);
            }
        }

        # check uplink
        my $uplink = _first_value('uplink', $data, $group_section, $default_section);
        if ( (!defined($uplink)) || (( lc($uplink) ne 'dynamic' ) && (!( $uplink =~ /(\d+,)*\d+/ ))) ) {
            add_problem( $WARN, "switches.conf | Switch uplink is invalid for switch $section" );
        }

        # check mode
        my @valid_switch_modes = ( 'testing', 'ignore', 'production', 'registration', 'discovery' );
        if ( !grep( { lc($_) eq lc($mode) } @valid_switch_modes ) ) {
            add_problem( $WARN, "switches.conf | Switch mode ($mode) is invalid for switch $section" );
        }

        # check role
        my $roles = _first_value('roles', $data, $group_section, $default_section);
        # if it's not empty it must be in the <cat1>=<role1>;<cat2>=<role2>;... format
        if ( defined($roles) && $roles !~ /^\s*$/ && $roles !~ /
            ^[\w\-]+=[\w\-]+         # at least one word=word
            (;[\w\-]+=[\w\-]+)*      # maybe more word=word in that case they must be prefixed by ;
            ;?               # optional ending ;
            $/x ) {
            add_problem(
                $WARN,
                "switches.conf | Roles parameter ($roles) is badly formatted for switch $section. "
                . "It should be: <category_name1>=<controller_role1>;<category_name2>=<controller_role2>;..."
            );
        }

    }
}

sub _first_value {
    my ($key, @hashes) = @_;
    foreach my $hash (@hashes) {
        return $hash->{$key} if exists $hash->{$key};
    }
    return undef;
}

=item billing

Validation related to the billing engine feature.

=cut

sub billing {
    # validate each profile has at least a billing tier if it has one or more billing source
    foreach my $profile_id (keys %Profiles_Config){
        my $profile = pf::Connection::ProfileFactory->_from_profile($profile_id);
        if($profile->getBillingSources() > 0 && @{$profile->getBillingTiers()} == 0){
            add_problem($WARN, "Profile $profile_id has billing sources configured but no billing tiers.");
        }
    }
    # validate billing tiers have the necessary configuration
    my @required_tier_params = qw(name description price role access_duration use_time_balance);
    foreach my $tier_id (keys %ConfigBillingTiers){
        foreach my $param (@required_tier_params){
            add_problem($WARN, "Missing parameter $param for billing tier $tier_id") unless($ConfigBillingTiers{$tier_id}{$param});
        }
    }
}

=item guests

Guest-related Checks

=cut

sub guests {

    # if we are going to send emails we must warn that MIME::Lite::TT must be installed
    my $guests_enabled = isenabled($Config{'registration'}{'guests_self_registration'});
    my $guest_require_email = ($guest_self_registration{$SELFREG_MODE_EMAIL} ||
                               $guest_self_registration{$SELFREG_MODE_SMS} ||
                               $guest_self_registration{$SELFREG_MODE_SPONSOR});
    if ($guests_enabled && $guest_require_email) {
        my $import_succesfull = try { require MIME::Lite::TT; };
        if (!$import_succesfull) {
            add_problem( $WARN,
                "Can't load MIME::Lite::TT. Emails to guests won't work. " .
                "Make sure to install it or disable the self-registered guest feature."
            );
        }
    }
}

=item connection_profiles

Make sure that connection profiles, if defined, have a filter and no unsupported parameters.

Make sure only one external authentication source is selected for each type.

=cut

# TODO: We might want to check if specified auth module(s) are valid... to do so, we'll have to separate the auth thing from the extension check.
sub connection_profiles {

    my $profile_params = qr/(?:locale |filter|logo|guest_self_reg|guest_modes|template_path|
        billing_tiers|description|sources|redirecturl|always_use_redirecturl|
        allowed_devices|allow_android_devices|
        reuse_dot1x_credentials|provisioners|filter_match_style|sms_pin_retry_limit|
        sms_request_limit|login_attempt_limit|block_interval|dot1x_recompute_role_from_portal|scan|root_module|preregistration|autoregister|access_registration_when_registered|device_registration|
        dpsk|default_psk_key|status|unreg_on_acct_stop)/x;
    my $validator = pf::validation::profile_filters->new;

    foreach my $connection_profile ( keys %Profiles_Config ) {
        my $data = $Profiles_Config{$connection_profile};
        # Checks for the non default profiles
        if ($connection_profile ne 'default' ) {
            add_problem( $WARN, "template directory '$install_dir/html/captive-portal/profile-templates/$connection_profile' for profile $connection_profile does not exist using default templates" )
                if (!-d "$install_dir/html/captive-portal/profile-templates/$connection_profile");

            add_problem ( $WARN, "missing filter parameter for profile $connection_profile" )
                if (!defined($data->{'filter'}) );
        }


        foreach my $key ( keys %$data ) {
            add_problem( $WARN, "invalid parameter $key for profile $connection_profile" )
                if ( $key !~ /$profile_params/ );
            if ($key eq 'filter') {
                foreach my $filter (@{$data->{filter}}) {
                    my ($rc, $message) = $validator->validate($filter);
                    unless ($rc) {
                        add_problem( $WARN, "Filter '$filter' is invalid for profile '$connection_profile': $message ");
                    }
                }
            }
        }

        my %external;
        # Verifing there is only one external source of each type
        foreach my $source ( grep { $_ && $_->class eq 'external' } map { pf::authentication::getAuthenticationSource($_) } @{$data->{'sources'}} ) {
            my $type = $source->{'type'};
            $external{$type} = 0 unless (defined $external{$type});
            $external{$type}++;
            add_problem ( $WARN, "many authentication sources of type $type are selected for profile $connection_profile" )
              if ($external{$type} > 1);
        }
    }
}

=item vlan_filter_rules

Make sure that the minimum parameters have been defined in access filter rules

=cut

sub vlan_filter_rules {
    require pf::access_filter::vlan;
    my %ConfigVlanFilters = %pf::access_filter::vlan::ConfigVlanFilters;
    foreach my $rule  ( sort keys  %ConfigVlanFilters ) {
        my $rule_data = $ConfigVlanFilters{$rule};
        if ($rule =~ /^[^:]+:(.*)$/) {
            my ($condition, $msg) = parse_condition_string($1);
            add_problem ( $WARN, "Cannot parse condition '$1' in $rule for vlan filter rule" . "\n" . $msg)
                if !defined $condition;
            add_problem ( $WARN, "Missing scope attribute in $rule vlan filter rule")
                if (!defined($rule_data->{'scope'}));
            add_problem ( $WARN, "Missing role attribute in $rule vlan filter rule")
                if (!defined($rule_data->{'role'}));
        } else {
            add_problem ( $WARN, "Missing filter attribute in $rule vlan filter rule")
                if (!defined($rule_data->{'filter'}));
            if (!defined($rule_data->{'operator'})) {
                add_problem ( $WARN, "Missing operator attribute in $rule vlan filter rule");
            } else {
                add_problem ( $WARN, "Missing value attribute in $rule vlan filter rule")
                    if (!defined($rule_data->{'value'}) && $rule_data->{'operator'} ne 'defined' && $rule_data->{'operator'} ne 'not_defined');
            }
        }
    }
}

=item apache_filter_rules

Make sure that the minimum parameters have been defined in apache filter rules

=cut

sub apache_filter_rules {
    my %ConfigApacheFilters = %pf::web::filter::ConfigApacheFilters;
    foreach my $rule  ( sort keys  %ConfigApacheFilters ) {
        if ($rule =~ /^\w+:(.*)$/) {
            add_problem ( $WARN, "Missing action attribute in $rule apache filter rule")
                if (!defined($ConfigApacheFilters{$rule}->{'action'}));
            add_problem ( $WARN, "Missing redirect_url attribute in $rule apache filter rule")
                if (!defined($ConfigApacheFilters{$rule}->{'redirect_url'}));
        } else {
            add_problem ( $WARN, "Missing filter attribute in $rule apache filter rule")
                if (!defined($ConfigApacheFilters{$rule}->{'filter'}));
            add_problem ( $WARN, "Missing method attribute in $rule apache filter rule")
                if (!defined($ConfigApacheFilters{$rule}->{'method'}));
            add_problem ( $WARN, "Missing value attribute in $rule apache filter rule")
                if (!defined($ConfigApacheFilters{$rule}->{'value'}));
            add_problem ( $WARN, "Missing operator attribute in $rule apache filter rule")
                if (!defined($ConfigApacheFilters{$rule}->{'operator'}));
        }
    }
}

=item db_check_version

Make sure the database schema matches the current version of PacketFence

=cut

sub db_check_version {
    eval {
        unless(pf::version::version_check_db()) {
            my $version = pf::version::version_get_current;
            my $db_version = pf::version::version_get_last_db_version || 'unknown';
            add_problem ( $FATAL, "The PacketFence database schema version '$db_version' does not match the current installed version '$version'\nPlease refer to the UPGRADE guide on how to complete an upgrade of PacketFence\n" );
        }
    };
    if($@) {
        add_problem($FATAL, "Cannot connect to database to check schema version: $@");
    }
}

=item valid_certs

Make sure the certificates used by Apache and RADIUS are valid

=cut

sub valid_certs {
    unless(-e "$generated_conf_dir/ssl-certificates.conf"){
        add_problem($WARN, "Cannot detect Apache SSL configuration. Not validating the certificates.");
        return;
    }
    unless(-e "$install_dir/raddb/eap.conf" || -e "$install_dir/conf/radiusd/eap.conf"){
        add_problem($WARN, "Cannot detect RADIUS SSL configuration. Not validating the certificates.");
        return;
    }

    my $haproxy_crt = "$install_dir/conf/ssl/server.pem";

    eval {
        if(pf::util::cert_expires_in($haproxy_crt)){
            add_problem($WARN, "The certificate used by haproxy ($haproxy_crt) has expired.\nRegenerate a new self-signed certificate or update your current certificate.");
        }
    };
    if($@){
        add_problem($WARN, "Cannot open the following certificate $haproxy_crt")
    }


    my $httpd_conf = read_file("$generated_conf_dir/ssl-certificates.conf");

    my ($httpd_crt, $radius_crt);

    if($httpd_conf =~ /SSLCertificateFile\s*(.*)\s*/){
        $httpd_crt = $1;
    }
    else{
        add_problem($WARN, "Cannot find the Apache certificate in your configuration.");
    }

    eval {
        if(pf::util::cert_expires_in($httpd_crt)){
            add_problem($WARN, "The certificate used by Apache ($httpd_crt) has expired.\nRegenerate a new self-signed certificate or update your current certificate.");
        }
    };
    if($@){
        add_problem($WARN, "Cannot open the following certificate $httpd_crt")
    }

    my $radius_conf;
    # if there is no file, we assume this is a first run
    my $radius_configured = -e "$install_dir/raddb/radiusd.conf" ? 1 : 0 ;
    if ( $radius_configured ) {

        $radius_conf = read_file("$install_dir/raddb/mods-enabled/eap");

        if($radius_conf =~ /certificate_file =\s*(.*)\s*/){
             $radius_crt = $1;
        }
        else{
            add_problem($WARN, "Cannot find the FreeRADIUS certificate in your configuration.");
        }

        eval {
            if(pf::util::cert_expires_in($radius_crt)){
                add_problem($WARN, "The certificate used by FreeRADIUS ($radius_crt) has expired.\n" .
                         "Regenerate a new self-signed certificate or update your current certificate.");
            }
        };
        if($@){
            add_problem($WARN, "Cannot open the following certificate $radius_crt")
        }
    }
    else {
        # not a problem per se, we just warn you
        print STDERR "Radius configuration is missing from raddb directory. Assuming this is a first run.\n";
    }
}

sub portal_modules {
    require pf::ConfigStore::PortalModule;
    require pf::Connection::ProfileFactory;
    require captiveportal::DynamicRouting::Application;
    require captiveportal::DynamicRouting::Factory;

    my $cs = pf::ConfigStore::PortalModule->new;
    foreach my $module (@{$cs->readAll("id")}){
        if(defined($module->{modules})){
            foreach my $sub_module (@{$module->{modules}}){
                unless($cs->hasId($sub_module)){
                    add_problem($WARN, "Portal Module $sub_module is used by ".$module->{id}." but is not declared.")
                }
            }
        }
        if($module->{type} eq "Root"){
            my $factory = captiveportal::DynamicRouting::Factory->new();
            my ($result, $msg) = $factory->check_cyclic($module->{id});
            unless($result) {
                add_problem($WARN, $msg);
            }
        }
    }
}

=item provisioning

Validate provisioning configuration

=cut

sub provisioning {
    require pf::ConfigStore::Provisioning;
    my $cs = pf::ConfigStore::Provisioning->new;
    foreach my $provisioner (@{$cs->readAll("id")}) {
        foreach my $device_id (@{$provisioner->{oses}}) {
            add_problem($WARN, "Device ID $device_id is invalid in provisioner ".$provisioner->{id}) unless(valid_fingerbank_device_id($device_id));
        }
    }
}

=item scan

Validate scan configuration

=cut

sub scan {
    require pf::ConfigStore::Scan;
    my $cs = pf::ConfigStore::Scan->new;
    foreach my $scanner (@{$cs->readAll("id")}) {
        foreach my $device_id (@{$scanner->{oses}}) {
            add_problem($WARN, "Device ID $device_id is invalid in scanner ".$scanner->{id}) unless(valid_fingerbank_device_id($device_id));
        }
    }
}

=item cluster

Validate the configuration of the cluster

=cut

sub cluster {
    require pf::cluster;
    require pf::ConfigStore::Interface;
    require pfconfig::namespaces::config::Cluster;
    require List::MoreUtils;

    unless($pf::cluster::cluster_enabled){
        return;
    }

    my $int_cs = pf::ConfigStore::Interface->new;
    my @ints = @{$int_cs->readAll('name')};
    my @servers = @pf::cluster::cluster_servers;
 
    my $hostname_map = pfconfig::namespaces::resource::clusters_hostname_map->new->build();
    my $cluster_name = $hostname_map->{$pf::cluster::host_id};

    unless($cluster_name) {
        add_problem($FATAL, "current host ($pf::cluster::host_id) isn't assigned to any cluster");
        return;
    }

    my $cluster_config = pfconfig::namespaces::config::Cluster->new(undef, $cluster_name);
    $cluster_config->build();

    unshift @servers, $cluster_config->{_CLUSTER}->{$cluster_name};

    unless(List::MoreUtils::any { $_->{host} eq $pf::cluster::host_id} @servers) {
        add_problem($FATAL, "current host ($pf::cluster::host_id) is missing from the cluster.conf file");
    }

    # Check each member configuration
    foreach my $server (@servers){
        my $server_name = $server->{host};
        if(!defined($server->{management_ip})){
            add_problem($FATAL, "management_ip is not defined for $server_name")
        }
        elsif(!valid_ip($server->{management_ip})){
            add_problem($FATAL, "management_ip is not a valid IP address for $server_name");
        }

        foreach my $int (@ints) {
            unless(exists($server->{"interface ".$int->{name}})) {
                add_problem($FATAL, "Interface $int->{name} is not defined for $server_name");
            }
        }
    }

}

=item valid_fingerbank_device_id

=cut

sub valid_fingerbank_device_id {
    require fingerbank::Model::Device;
    require pf::error;
    my ($device_id) = @_;
    my ($status, $result) = fingerbank::Model::Device->read($device_id);
    if($status == $STATUS::NOT_FOUND) {
        return $FALSE;
    }
    else {
        return $TRUE;
    }
}

=head2 pfdetect

pfdetect

=cut

sub pfdetect {
    my $file = $pfdetect_config_file;
    my $ini = pf::IniFiles->new(-file => $file, -allowempty => 1);
    unless ($ini) {
        my $error_msg = join("\n", @pf::IniFiles::errors, "");
        add_problem($FATAL, "$file: Invalid config file");
        return;
    }

    my $builder = pf::config::builder::pfdetect->new();
    my ($errors, $data) = $builder->build($ini);
    for my $err (@{ $errors // [] }) {
        my $error_msg =  "$file: $err->{rule}) $err->{message}";
        add_problem($WARN, $error_msg);
    }
}

=head2 validate_access_filters

Validate Access Filters

=cut

sub validate_access_filters {
    my $builder = pf::config::builder::scoped_filter_engines->new();
    while (my ($f, $cs) = each %pf::constants::filters::CONFIGSTORE_MAP) {
        next if $f eq 'apache-filters';
       my $ini = $cs->configIniFile();
       my ($errors, undef) = $builder->build($ini);
       if ($errors) {
            foreach my $err (@$errors) {
                add_problem($WARN, "$f: $err->{rule}) $err->{message}");
            }
       }
    }
    return ;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
# vim: set tabstop=4:
# vim: set autoindent:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
