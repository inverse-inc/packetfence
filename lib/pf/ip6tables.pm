package pf::ip6tables;

=head1 NAME

pf::ip6tables - module for ip6tables rules management.

=cut

=head1 DESCRIPTION

pf::ip6tables contains the functions necessary to manipulate the ip6tables service

=head1 CONFIGURATION AND ENVIRONMENT

F<pf.conf> configuration file and ip6tables template F<ip6tables.conf>.

=cut

use strict;
use warnings;

use JSON;
use Readonly;
use File::Slurp qw(read_file);
use File::Path qw(make_path);
use File::Basename;
use Switch;
use Symbol qw(gensym);
use IPC::Open3 qw(open3);
use Data::Dumper;
use Template;
use Scalar::Util 'reftype';
use Try::Tiny;
use Sys::Hostname;

use pf::log;
use pf::constants;
use pf::util;
use pf::config qw(
    $management_network
    @portal_ints
);
use pf::file_paths qw(
    $generated_conf_dir
    $conf_dir
    $ip6table_custom_config_file
    $generated_ip6tables_conf_dir
);

BEGIN {
  use Exporter ();
  our ( @ISA, @EXPORT );
  @ISA = qw(Exporter);
  @EXPORT = qw(
    ip6tables_configreload
    ip6tables_haproxy_portal_rules
    ip6tables_generate_config
    ip6tables_save
    ip6tables_restore
    ip6tables_services_rules
    ip6tables_flush_to_default
    ip6tables_services_rules
    ip6tables_haproxy_portal_rules
    util_management_network_ipv6_is_set
  );
}

=item iptables_configreload

Reload the config

=cut

sub ip6tables_configreload {
    my ($force) = @_;
    my $logger = get_logger();
    $logger->info( "Start config reload" );
    if ($force eq 1) {
        ip6tables_flush_to_default();
        ip6tables_services_rules("REMOVE");
    }
    ip6tables_services_rules("ADD");
    ip6tables_generate_config();
}

sub ip6tables_flush_to_default {
    my $logger = get_logger();
    safe_pf_run(qw(sudo ip6tables -F));
    safe_pf_run(qw(sudo ip6tables -X));
    safe_pf_run(qw(sudo ip6tables -t raw -F));
    safe_pf_run(qw(sudo ip6tables -t raw -X));
    safe_pf_run(qw(sudo ip6tables -P INPUT ACCEPT));
    safe_pf_run(qw(sudo ip6tables -P FORWARD ACCEPT));
    safe_pf_run(qw(sudo ip6tables -P OUTPUT ACCEPT));
    $logger->info( "Ip6tables have been flush to default" );
    return 1;
}

sub ip6tables_save {
    my ($class, $save_file) = @_;
    my $logger = get_logger();
    $logger->info( "saving existing ip6tables to " . $save_file );
    safe_pf_run("/usr/sbin/ip6tables-save", '-t', 'raw', { stdout => $save_file, stdout_append => 1});
    safe_pf_run("/usr/sbin/ip6tables-save", '-t', 'filter', { stdout => $save_file, stdout_append => 1});
}

sub ip6tables_restore {
    my ($restore_file) = @_;
    my $logger = get_logger();
    if ( -r $restore_file ) {
        $logger->info( "restoring ip6tables from " . $restore_file );
        safe_pf_run("/usr/sbin/ip6tables-restore", { stdin => $restore_file });
    }
}

=item ip6tables_generate_config

Generate the iptable config from iptables service config.

=cut

sub ip6tables_generate_config {
    my ($self) = @_;
    my $logger = get_logger();

    # Check for and load content from custom specific file if it exists
    my $custom = util_add_custom_config_from_file( $ip6table_custom_config_file );
    if ($custom) {
        $logger->info( "Successfully loaded custom configuration from $ip6table_custom_config_file" );
    } else {
        $logger->info( "No custom configuration file ($ip6table_custom_config_file) found" );
    }

    util_generated_ip6tables_fix_dir_permissions();
    my %configs;
    # Get content from service generated json config files
    my @config_files = read_dir_recursive($generated_ip6tables_conf_dir);
    if (@config_files) {
        foreach my $conf ( @config_files ) {
            my $json_text = read_file($generated_ip6tables_conf_dir."/".$conf);
            my $data = decode_json($json_text);
            my $conf_name = $data->{name};
            $configs{$conf_name} = $data;
        }
    }

    # Merge configurations
    my %merged = (
        filter => { INPUT => [], FORWARD => [], OUTPUT => [], RFC3964_IPv4 => [] },
        raw => { PREROUTING => [], OUTPUT => [] }
    );

    # Log IPv6 status on management network (SSH is handled by IPv4 iptables)
    if ( util_management_network_ipv6_is_set("generate_config") ) {
        $logger->info("IPv6 configured on management interface");
    } else {
        $logger->debug("IPv6 not configured on management interface");
    }

    foreach my $name (sort keys %configs) {
        my $fw = $configs{$name};
        # Merge filter rules if they exist
        if ($fw->{filter}) {
            foreach my $chain (keys %{$merged{filter}}) {
                push @{$merged{filter}{$chain}}, @{$fw->{filter}{$chain}} if $fw->{filter}{$chain};
            }
        }
        # Merge raw rules if they exist
        if ($fw->{raw}) {
            foreach my $chain (keys %{$merged{raw}}) {
                push @{$merged{raw}{$chain}}, @{$fw->{raw}{$chain}} if $fw->{raw}{$chain};
            }
        }
    }

    # Remove duplicates while preserving order
    foreach my $table (keys %merged) {
        foreach my $chain (keys %{$merged{$table}}) {
            my @unique_rules;
            my %seen;
            foreach my $rule (@{$merged{$table}{$chain}}) {
                push @unique_rules, $rule unless $seen{$rule}++;
            }
            $merged{$table}{$chain} = \@unique_rules;
        }
    }

    # Process template
    my $tt = Template->new(ABSOLUTE => 1);
    $tt->process(
        "$conf_dir/ip6tables.conf.tt",
        {
            configs => \%configs,
            custom  => $custom,
            merged  => \%merged
        },
        "$generated_conf_dir/ip6tables_generated_rules.conf"
    ) or die $tt->error();

    ip6tables_restore("$generated_conf_dir/ip6tables_generated_rules.conf");
}

=item ip6tables_services_rules

Iptables apply rules according to running services
need to get services that are running and use the dedicated function to restart accordingly

=cut

sub ip6tables_services_rules {
  my $logger = get_logger();
  my $action = shift;
  my $services = [qw(
      packetfence-haproxy-portal.service
  )];
  my $states = util_getServiveState($services,[qw(Id ActiveState)]);
  foreach my $state ( @{ $states } ) {
    if ( $state->{"ActiveState"} eq "active" ) {
      $logger->info("$state->{'Id'} is active");
      switch( $state->{'Id'} ) {
        case "packetfence-haproxy-portal.service"        { ip6tables_haproxy_portal_rules($action); }
        else { $logger->info( "The service $state->{'Id'} is not using Firewalld for its configuration" ) }
      }
    }
  }
}

=item ip6tables_haproxy_portal_rules

Iptable rules for haproxy portal service

=cut

sub ip6tables_haproxy_portal_rules {
    my $service_name = "haproxy_portal_rules";
    my $action = shift;

    if ( $action eq "REMOVE" ) {
       util_remove_service_rules($service_name);
       return;
    }

    my $logger = get_logger();
    my $chains = util_create_ip6_chains();
    if ( @portal_ints ) {
        # 'portal' interfaces handling
        $chains->{'name'} = $service_name;
        foreach my $portal_interface ( @portal_ints ) {
            my $tint = $portal_interface->tag("int");
            util_safe_push( "-i $tint -p tcp -m tcp --dport 80 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
            util_safe_push( "-i $tint -p tcp -m tcp --dport 443 -j ACCEPT", $chains->{'filter'}{'INPUT'} );
        }
    } else {
        $logger->warn("Service $service_name: Portal Ints are not set.");
    }

    if ($chains->{'name'} ne "") {
        # Convert to JSON and save to file
        util_create_service_rules($chains);
    }
}

###################
# UTILS
###################

=item util_getServiveState

Get state of services

=cut

sub util_getServiveState {
    my ($services, $props) = @_;
    return [] if @$services == 0;
    my @args = ((map { ('-p' => $_) } @$props), @$services);
    my $pid = open3(my $chld_in, my $chld_out, my $chld_err = gensym, 'sudo', 'systemctl', 'show', @args);
    waitpid( $pid, 0 );
    my $child_exit_status = $? >> 8;
    my $out = do {
        local $/ = undef;
        <$chld_out>
    };
    close($chld_in);
    close($chld_out);
    close($chld_err);

    my @states;
    my $state = {};
    for my $line (split '\n', $out) {
        if ($line eq '') {
            push @states, $state;
            $state = {};
            next;
        }

        my ($k, $v) = split('=', $line, 2);
        $state->{$k} = $v;
    }

    push @states, $state;
    return \@states;
}

=item util_create_ip6_chains

Create default iptables chain

=cut

sub util_create_ip6_chains {
    my %chains = (
        'name'   => "",
        filter => { INPUT => [], FORWARD => [], OUTPUT => [], RFC3964_IPv4 => [] },
        raw => { PREROUTING => [], OUTPUT => [] }
    );
    return \%chains;
}

=item util_is_management_network_set

Function to check if management interface is set

=cut

sub util_management_network_is_set {
    my ( $service_name ) = @_ ;
    my $logger = get_logger();
    if ( !ref($management_network) || !exists $management_network->{Tint} || $management_network->{Tint} eq "" ) {
        $logger->warn("Service $service_name: Management Interface is not set.");
        return 0;
    }
    return 1;
}

=item util_management_network_ipv6_is_set

Function to check if management interface has IPv6 configured

=cut

sub util_management_network_ipv6_is_set {
    my ( $service_name ) = @_ ;
    my $logger = get_logger();

    # First check if management interface exists
    return 0 unless util_management_network_is_set($service_name);

    # Check if IPv6 is configured on management interface
    my $ipv6_address = $management_network->tag("ipv6_address");
    my $ipv6_prefix = $management_network->tag("ipv6_prefix");

    if ( !defined($ipv6_address) || $ipv6_address eq "" ||
         !defined($ipv6_prefix) || $ipv6_prefix eq "" ) {
        $logger->debug("Service $service_name: IPv6 not configured on management interface.");
        return 0;
    }

    return 1;
}

=item util_add_custom_config_from_file

Function to load and validate custom config from file

=cut

sub util_add_custom_config_from_file {
    my ( $file , $configs_ref ) = @_;
    my $logger = get_logger();

    return 0 unless -e $file;

    my %empty_hash;
    try {
        my $filename = fileparse($file);
        my $json_content = read_file($file);
        my $custom_config = decode_json($json_content);

        $custom_config->{'name'}=$filename;

        my %allowed_structure = (
            filter => { INPUT => 1, FORWARD => 1, OUTPUT => 1, RFC3964_IPv4 => 1 },
            raw => { PREROUTING => 1, OUTPUT => 1 }
        );

        my $has_rules = 0;
        foreach my $table (keys %$custom_config) {
            next if $table eq 'name';

            unless (exists $allowed_structure{$table}) {
                printf ("Invalid table '$table' in $filename");
                $logger->warn("Invalid table '$table' in $filename");
                return \%empty_hash;
            }

            foreach my $chain (keys %{$custom_config->{$table}}) {
                unless (exists $allowed_structure{$table}{$chain}) {
                    $logger->warn("Invalid chain '$chain' in table '$table' in $filename");
                    return \%empty_hash;
                }

                $has_rules = 1 if @{$custom_config->{$table}{$chain}};
            }
        }

        if ($has_rules) {
            $logger->info("Rules available  in $file");
            return $custom_config;
        } else {
            $logger->warn("No rules available in $file");
        }

        $logger->warn("Config in $file contains no rules");
        return \%empty_hash;
    } catch {
        my $error = shift;
        printf("Failed to process $file: $error");
        $logger->warn("Failed to process $file: $error");
        return \%empty_hash;
    };
}

=item util_create_service_rules

Save Chains Hash to JSON file

=cut

# Function definition
sub util_create_service_rules {
    my $chains_ref = shift;
    my $logger = get_logger();

    # Convert to JSON with pretty formatting
    my $json = JSON->new->pretty->canonical->encode($chains_ref);

    # Add .json extension if not present
    my $filename = $generated_ip6tables_conf_dir."/".$chains_ref->{'name'}.'.json';

    # Create directory if it doesn't exist
    unless (-d $generated_ip6tables_conf_dir) {
        make_path($generated_ip6tables_conf_dir) or die $logger->error("Could not create directory $generated_ip6tables_conf_dir: $!");
    }

    # Write to file
    open(my $fh, '>', $filename) or die $logger->error("Could not open $filename: $!");
    print $fh $json;
    close($fh);

    # Verify file was created
    unless (-e $filename) {
        die $logger->error("Failed to create JSON file $filename");
    }
    util_generated_ip6tables_fix_dir_permissions();
    $logger->info("Successfully saved chains to $filename");
}


=item util_remove_service_rules

Remove service rules JSON file

=cut

sub util_remove_service_rules {
    my $service_name = shift;
    my $logger = get_logger();

    # Add .json extension if not present
    my $filename = $generated_ip6tables_conf_dir."/".$service_name.'.json';
    if (-e $filename) {
        if (unlink $filename) {
            $logger->info("Successfully removed $filename");
            return 1;
        } else {
            $logger->error("Error removing $filename: $!");
            return 0;
        }
    } else {
        $logger->warn("$filename does not exist");
        return 0;
    }
}

=item util_safe_push

Add value only if not other equal value are in array

=cut

sub util_safe_push {
    my ($value, $array_ref) = @_;
    my $logger = get_logger();

    if (defined $array_ref && reftype($array_ref) eq 'ARRAY') {
        my $normalized_value = _normalize_rule($value);

        foreach my $item (@$array_ref) {
            return if _normalize_rule($item) eq $normalized_value;
        }
        push @$array_ref, $value;
    } else {
        $logger->warn("Debug \$array_ref: \n" . Dumper($array_ref) . "\n\nand the value is \n". Dumper($value));
    }
}

sub _normalize_rule {
    my $rule = shift;
    $rule =~ s/\s*,\s*/,/g;
    $rule =~ s/\s+/ /g;
    $rule =~ s/^\s+|\s+$//g;
    return $rule;
}

=item util_generated_ip6tables_fix_dir_permissions

Fix generated_ip6tables_conf_dir permissions

=cut

sub util_generated_ip6tables_fix_dir_permissions {
    safe_pf_run('sudo', 'chmod', '02770', $generated_ip6tables_conf_dir);
    safe_pf_run('sudo', 'chown', 'root:pf', '-R', $generated_ip6tables_conf_dir);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
