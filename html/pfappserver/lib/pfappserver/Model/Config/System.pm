package pfappserver::Model::Config::System;

=head1 NAME

pfappserver::Model::Config::System - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use Moose;
use namespace::autoclean;
use Net::Netmask;

use pf::log;
use pf::error qw(is_error is_success);
use pf::util;

our $DB_SERVICE_NAME = "packetfence-mariadb";

extends 'Catalyst::Model';

=head1 METHODS

=head2 check_mysqld_status

=cut

sub check_mysqld_status {
    my ( $self ) = @_;
    my $logger = get_logger();
    my $mainpid = safe_pf_run(qw(systemctl show -p MainPID), $DB_SERVICE_NAME);
    chomp($mainpid);
    my (undef,$pid) = split('=', $mainpid);
    $pid = 0 if ( !$pid );
    $logger->info("systemctl show -p MainPID $DB_SERVICE_NAME returned $pid");

    return ($pid);
}

=head2 getDefaultGateway

=cut

sub getDefaultGateway {
    my ($self) = @_;
    my $logger = get_logger();

    my $default_gateway = (split(" ", safe_pf_run(qw(sudo ip route show to), '0/0')))[2];
    $logger->debug("Default gateway: " . $default_gateway);

    return $default_gateway if defined($default_gateway);
}

=head2 getInterfaceForGateway

=cut

sub getInterfaceForGateway {
    my ( $self, $interfaces_ref, $gateway ) = @_;
    my $logger = get_logger();

    foreach my $interface ( sort keys(%$interfaces_ref) ) {
        next if ( !($interfaces_ref->{$interface}->{'is_running'}) );

        my $network = $interfaces_ref->{$interface}->{'network'};
        my $netmask = $interfaces_ref->{$interface}->{'netmask'};

        next if(!defined($network) or !defined($netmask));

        my $subnet  = new Net::Netmask($network, $netmask);

        return $interface if ( $subnet->match($gateway) );
    }

    return;
}

=head2 setDefaultRoute

=cut

sub setDefaultRoute {
    my ($self, $gateway) = @_;
    my $logger = get_logger();

    my $_EXIT_CODE_EXISTS = 7;

    my ($status, $status_msg);

    # Check for valid IP format
    if ( !valid_ip($gateway) ) {
        $status_msg = "Invalid IP format for gateway";
        $logger->warn("$status_msg");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    my $cmd = "sudo ip route replace to default via $gateway 2>&1";
    $logger->debug("Replace default gateway: $cmd");
    $status = safe_pf_run(qw(sudo ip route replace to default via), $gateway , {accepted_exit_status => [ $_EXIT_CODE_EXISTS ], redirect_stderr_to_stdout => 1});

    # Everything goes as expected
    if (defined($status)) {
        $status_msg = "New default gateway successfully injected";
        $logger->info($status_msg);
        return ($STATUS::OK, $status_msg);
    }
    # Something went wrong
    else {
        $status_msg = "Something went wrong while injecting default gateway";
        $logger->warn($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }
}

=head2 start_mysqld_service

=cut

sub start_mysqld_service {
    my ( $self ) = @_;
    my $logger = get_logger();

    my ($status, $status_msg);

    # Check to make sure that MySQLd is not already running
    if ( $self->check_mysqld_status ) {
        $status_msg = "MySQL server seems to be already running, did not started it";
        $logger->info($status_msg);
        return ($STATUS::OK, $status_msg);
    }

    # please keep LANG=C in case we need to fetch the output of the command
    my $cmd = "setsid sudo service $DB_SERVICE_NAME start 2>&1";
    $logger->debug("Starting $DB_SERVICE_NAME service: $cmd");
    $status = safe_pf_run(qw(setsid sudo service), $DB_SERVICE_NAME, 'start');

    # Everything goes as expected
    if ( defined($status) ) {
        $status_msg = "MySQL server successfully started";
        $logger->info($status_msg);
        return ($STATUS::OK, $status_msg);
    }
    # Something went wrong
    else {
        $status_msg = "Something went wrong while starting MySQL server";
        $logger->warn($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }
}

=head2 restart_pfconfig

=cut

sub restart_pfconfig {
    my ( $self ) = @_;
    my $logger = get_logger();

    my ($status, $status_msg);

    my $cmd = "setsid sudo service packetfence-config restart 2>&1";
    $logger->debug("Restarting packetfence-config service: $cmd");
    $status = safe_pf_run(qw(setsid sudo service packetfence-config restart));

    # Everything goes as expected
    if ( defined($status) ) {
        $status_msg = "packetfence-config successfully restarted";
        $logger->info($status_msg);
        return ($STATUS::OK, $status_msg);
    }
    # Something went wrong
    else {
        $status_msg = "Something went wrong while restarting packetfence-config";
        $logger->warn($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }
}

=head2 write_network_persistent

Write the persistent OS network configuration of the interfaces.

  $system->write_network_persistent($interfaces, $gateway, removed => \@interfaces);

removed lists the interfaces that were just deleted: they are not in
$interfaces anymore and must not be kept in the OS configuration.

=cut

sub write_network_persistent {
    my ( $self, $interfaces_ref, $gateway, %options ) = @_;
    my $logger = get_logger();

    my ($status, $status_msg, $systemObj);

    # Check if gateway is valid
    my $gateway_interface = $self->getInterfaceForGateway($interfaces_ref, $gateway);
    if ( !$gateway_interface ) {
        $status_msg = "Invalid gateway. Doesn't belong to any running and configured interface";
        $logger->error("$status_msg");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # Inject gateway for live usage
    ($status, $status_msg) = $self->setDefaultRoute($gateway);
    if ( is_error($status) ) {
        $logger->error("$status_msg");
        return ($status, $status_msg);
    }

    # Instantiate an object for the correct OS
    ($status, $systemObj) = pfappserver::Model::Config::SystemFactory->getSystem();
    return ($status, $systemObj) if ( is_error($status) );

    # Write persistent network configurations
    ($status, $status_msg) = $systemObj->writeNetworkConfigs($interfaces_ref, $gateway, $gateway_interface, %options);
    return ($status, $status_msg) if ( is_error($status) );

    $status_msg = "Persistent network configurations successfully written";
    $logger->info("$status_msg");
    return ($STATUS::OK, $status_msg);
}


package pfappserver::Model::Config::SystemFactory;


=head2 NAME

pfappserver::Model::Config::SystemFactory

=head2 DESCRIPTION

Moose class.

=cut

use Moose;
use pf::log;
use pf::util;

=head1 METHODS

=head2 _checkOs

Checks running operating system

=cut

sub _checkOs {
    my ( $self ) = @_;

    # Default to undef
    my $os;

    return ucfirst(host_os_detection());
}

=head2 getSystem

Obtain a system object suited for your system.

=cut

sub getSystem {
    my ( $self ) = @_;
    my $logger = get_logger();

    my $status_msg;

    my $os = $self->_checkOs();

    if (defined($os)) {
        my $system = "pfappserver::Model::Config::System::$os";
        my $systemObj = $system->new();
        $logger->info("Instantiate a new object of type $os");
        return ($STATUS::OK, $systemObj);
    }

    $status_msg = "This OS is not supported by PacketFence";
    $logger->error("$status_msg | Cannot instantiate an object of this type");

    return ($STATUS::NOT_IMPLEMENTED, $status_msg);
}


package pfappserver::Model::Config::System::Role;


=head2 NAME

pfappserver::Model::Config::System::Role

=head2 DESCRIPTION

Moose class implemeting roles.

=cut

use Moose::Role;
use pf::log;

requires qw(writeNetworkConfigs);


package pfappserver::Model::Config::System::Rhel;

=head3 NAME

pfappserver::Model::Config::System::Rhel

=head3 DESCRIPTION

Moose class derivated from role for OS specific methods

=cut

use Moose;

use pf::util;
use pf::log;

with 'pfappserver::Model::Config::System::Role';

our $_network_conf_dir    = "/etc/sysconfig/";
our $_interfaces_conf_dir = "network-scripts/";
our $_network_conf_file   = "network";
our $_interface_conf_file = "ifcfg-";
our $var_dir              = "/usr/local/pf/var/";

=head1 METHODS

=head2 writeNetworkConfigs

=cut

sub writeNetworkConfigs {
    my ( $self, $interfaces_ref, $gateway, $gateway_interface ) = @_;
    my $logger = get_logger();

    my $status_msg;
    my $interface_gateway;
    my $interface_defroute ="no";
    while (my ($interface, $interface_values) = each %$interfaces_ref) {
        next if ( !$interface_values->{is_running} );
        # interface_rhel.tt always emits BOOTPROTO=static + IPADDR=, so an
        # address-less interface would overwrite its real IPADDR with an empty
        # one. Callers pass get('all'), so a transiently address-less interface
        # gets swept in even when only another one is being changed.
        # interface_debian.tt already guards its stanzas the same way.
        if ( !$interface_values->{'ipaddress'} && !$interface_values->{'ipv6_address'} ) {
            $logger->warn("Interface $interface has no address, keeping its existing persistent configuration");
            next;
        }
        if ($gateway_interface eq $interface) {
            $interface_defroute = "yes";
            $interface_gateway = $gateway;
        } else {
            $interface_defroute = "no";
            $interface_gateway = undef;
        }
        my %vars = (
            logical_name => $interface,
            vlan_device  => $interface_values->{'vlan'},
            hwaddr       => $interface_values->{'hwaddress'},
            ipaddr       => $interface_values->{'ipaddress'},
            netmask      => $interface_values->{'netmask'},
            ipv6_address => $interface_values->{'ipv6_address'},
            ipv6_prefix  => $interface_values->{'ipv6_prefix'},
            defroute     => $interface_defroute,
            gateway      => $interface_gateway,
        );

        my $template = Template->new({
            INCLUDE_PATH    => "/usr/local/pf/html/pfappserver/root/interface",
            OUTPUT_PATH     => $var_dir,
        });
        my $outfile = $_interface_conf_file.$interface;

        $template->process( "interface_rhel.tt", \%vars, $outfile );

        if ( $template->error() ) {
            $status_msg = "Error while writing system network interfaces configuration";
            $logger->error("$status_msg");
            return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
        }
        my $interface_config_file = "$_network_conf_dir$_interfaces_conf_dir$_interface_conf_file$interface";
        my $filter = variableExcludeRegex("$var_dir$outfile");
        safe_pf_run('grep', '--no-filename', '-Pv', $filter, $interface_config_file, {stdout => "$var_dir$outfile", stdout_append => 1, accepted_exit_status => [1]});
        my $status = safe_pf_run('sudo', 'tee', $interface_config_file, {stdin => "$var_dir$outfile", redirect_stderr_to_stdout => 1});
        # Something went wrong
        if ( !(defined($status) ) ) {
            $status_msg = "Something went wrong while writing the network interface file";
            $logger->warn($status_msg);
            return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
        }
    }

    if ( !(-e $_network_conf_dir.$_network_conf_file) ) {
        $status_msg = "Error while writing system's default gateway";
        $logger->error($status_msg ." | ". $_network_conf_dir.$_network_conf_file ." don't exists");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    open IN, '<', $_network_conf_dir.$_network_conf_file;
    my @content = <IN>;
    close IN;

    @content = grep { !/^GATEWAY=/ } @content;
    open(my $out, "|-", "sudo tee $_network_conf_dir$_network_conf_file > /dev/null");
    if (!$out) {
        $status_msg = "Something went wrong while writing the network file";
        $logger->warn($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }
    print $out @content;
    print $out "GATEWAY=$gateway\n";
    close $out;

    $logger->info("System network configurations successfully written");
    return $STATUS::OK;
}

sub variableExcludeRegex {
    my ($file) = @_;
    open IN, '<', $file;
    chomp(my @vars = <IN>);
    close IN;
    my @excludes = map { s/=.*//;$_ } grep { $_ ne ''  } @vars;
    return '^(?:(?:' . join('|', @excludes) . ')=|$)';
}

package pfappserver::Model::Config::System::Debian;


=head3 NAME

pfappserver::Model::Config::System::Debian

=head3 DESCRIPTION

Moose class derivated from role for OS specific methods

=cut

use Moose;

use pf::util;
use pf::log;

with 'pfappserver::Model::Config::System::Role';

our $_network_conf_dir    = "/etc/network/";
our $_network_conf_file   = "interfaces";
our $var_dir              ="/usr/local/pf/var/";

=head1 METHODS

=head2 writeNetworkConfigs

=cut

sub writeNetworkConfigs {
    my ( $self, $interfaces_ref, $gateway, $gateway_interface, %options ) = @_;
    my $logger = get_logger();

    my $status_msg;

    my $vars = {
        interfaces          => $interfaces_ref,
        gateway             => $gateway,
        gateway_interface   => $gateway_interface,
    };

    my $template = Template->new({
        INCLUDE_PATH    => "/usr/local/pf/html/pfappserver/root/interface",
    });
    my $generated = '';
    $template->process( "interface_debian.tt", $vars, \$generated ) || $logger->error($template->error());

    if ( $template->error() ) {
        $status_msg = "Error while writing system network interfaces configuration";
        $logger->error("$status_msg");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }

    # Keep what PacketFence doesn't manage (bonds, bridges, MTU, DNS, other interfaces, ...)
    my $existing = '';
    if (open(my $fh, '<', "$_network_conf_dir$_network_conf_file")) {
        local $/;
        $existing = <$fh> // '';
        close($fh);
    }
    my $content = merge_interfaces_config($generated, $existing, [ keys %{$interfaces_ref // {}} ], $options{removed});

    # A file included by /etc/network/interfaces (ex: 50-cloud-init) may also define
    # an interface PacketFence configures: ifupdown then sees both definitions
    my $sourced = interfaces_in_sourced_files($existing, $_network_conf_dir);
    for my $item (grep { $_->{type} eq 'iface' && $_->{name} ne 'lo' } @{parse_interfaces_config($generated)}) {
        next unless my $file = $sourced->{$item->{name}};
        $logger->warn("Interface $item->{name} is configured by PacketFence in $_network_conf_dir$_network_conf_file and also defined in $file, which it includes. Remove it from $file; on a cloud image, disable the network configuration of cloud-init.");
    }

    if (open(my $fh, '>', "$var_dir$_network_conf_file")) {
        print $fh $content;
        close($fh);
    } else {
        $status_msg = "Error while writing system network interfaces configuration";
        $logger->error("$status_msg: $!");
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }
    my $status = safe_pf_run('sudo', 'tee', "$_network_conf_dir$_network_conf_file", {stdin => "$var_dir$_network_conf_file", redirect_stderr_to_stdout => 1});
    # Everything goes as expected
    if ( defined($status) ) {
        $status_msg = "Interface creation successfull";
        $logger->info($status_msg);
        return ($STATUS::OK, $status_msg);
    }
    # Something went wrong
    else {
        $status_msg = "Something went wrong while writing the network interface file";
        $logger->warn($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, $status_msg);
    }
}

# Options of an iface stanza that PacketFence manages, the generated value always wins
our %MANAGED_OPTIONS = map { $_ => 1 } qw(address netmask gateway broadcast network);

=head2 parse_interfaces_config

Parse an /etc/network/interfaces content (ifupdown) into a list of items:
iface/mapping stanzas with their option lines, auto/allow-* lines, source lines
and anything else.

A block of comment lines is kept in the C<comments> of the item that follows
it; an indented comment inside a stanza is kept as one of its option lines.
A block followed by an empty line (ex: the header of the file), and the
comments at the end of the content, form a C<comment> item of their own.

=cut

sub parse_interfaces_config {
    my ($content) = @_;
    my @items;
    my $stanza;
    my @comments;
    $content //= '';
    $content =~ s/\\\n\s*/ /g;
    for my $line (split /\n/, $content) {
        if ($line =~ /^\s*$/) {
            push @items, { type => 'comment', comments => [ splice(@comments) ] } if @comments;
            next;
        }
        if ($line =~ /^(\s*)#/) {
            my $indented = length $1;
            $line =~ s/^\s+|\s+$//g;
            if ($stanza && $indented && !@comments) {
                push @{$stanza->{options}}, $line;
            } else {
                push @comments, $line;
            }
            next;
        }
        $line =~ s/^\s+|\s+$//g;
        my ($keyword, @args) = split /\s+/, $line;
        my $item;
        if ($keyword eq 'iface') {
            $item = $stanza = { type => 'iface', name => $args[0], family => $args[1] // '', method => $args[2] // '', header => $line, options => [] };
        } elsif ($keyword eq 'mapping') {
            $item = $stanza = { type => 'mapping', name => $args[0], header => $line, options => [] };
        } elsif ($keyword eq 'auto' || $keyword =~ /^allow-/) {
            undef $stanza;
            $item = { type => 'auto', keyword => $keyword, names => \@args };
        } elsif ($keyword eq 'source' || $keyword eq 'source-directory') {
            undef $stanza;
            $item = { type => 'source', line => $line };
        } elsif ($stanza) {
            # A comment between the options of a stanza stays in the stanza
            push @{$stanza->{options}}, splice(@comments), $line;
            next;
        } else {
            $item = { type => 'other', line => $line };
        }
        $item->{comments} = [ splice(@comments) ];
        push @items, $item;
    }
    push @items, { type => 'comment', comments => [ @comments ] } if @comments;
    return \@items;
}

=head2 merge_interfaces_config

Merge the configuration generated for the interfaces managed by PacketFence
with the existing /etc/network/interfaces so that what PacketFence doesn't
manage is not lost:

 - stanzas of the interfaces not managed by PacketFence are kept as is
 - the extra options (mtu, bond-*, bridge_ports, dns-*, ...) of a managed
   interface are kept, PacketFence only sets its address, netmask and gateway
 - a managed interface without an address keeps its non static stanza (ex:
   manual for a bond member), a static one is dropped as its IP was removed
 - source and source-directory lines are kept
 - the stanzas and auto lines of the removed interfaces (just deleted in
   PacketFence) are dropped
 - a managed interface for which PacketFence only generates C<inet manual>
   (no address) keeps an existing non static header, ex: C<inet dhcp>
 - comments are kept with the item they precede; the comments of an auto or
   allow-* line go with the stanza of its first interface, since the auto
   lines are grouped at the top

=cut

sub merge_interfaces_config {
    my ($generated, $existing, $managed_names, $removed_names) = @_;
    my %managed = map { $_ => 1 } ('lo', @{$managed_names // []});
    my %removed = map { $_ => 1 } grep { !$managed{$_} } @{$removed_names // []};
    my $new = parse_interfaces_config($generated);
    my $old = parse_interfaces_config($existing);

    my (@out, %new_iface, %seen_auto);
    for my $item (@$new) {
        $new_iface{"$item->{name} $item->{family}"} = $item if $item->{type} eq 'iface';
    }
    my %old_iface = map { ("$_->{name} $_->{family}" => $_) } grep { $_->{type} eq 'iface' } @$old;

    my $keep_old = sub {
        my ($item) = @_;
        return $item->{type} eq 'mapping' || $item->{type} eq 'other' if $item->{type} ne 'iface';
        return 0 if $new_iface{"$item->{name} $item->{family}"} || $removed{$item->{name}};
        return 0 if $managed{$item->{name}} && ($item->{method} eq 'static' || $item->{name} eq 'lo');
        return 1;
    };
    # Interfaces that get a stanza: the comments of their auto lines go with it
    my %has_stanza = map { ($_->{name} => 1) } (values %new_iface, grep { $_->{type} eq 'iface' && $keep_old->($_) } @$old);
    my %stanza_comments;

    # The comments at the top of the file (its header) stay at the top
    my $leading = 0;
    $leading++ while $leading < @$old && $old->[$leading]{type} eq 'comment';
    for my $item (@$old[0 .. $leading - 1]) {
        push @out, @{$item->{comments}}, '';
    }
    for my $item (grep { $_->{type} eq 'source' } @$old) {
        push @out, @{$item->{comments} // []}, $item->{line};
    }
    for my $item (grep { $_->{type} eq 'auto' } @$new, @$old) {
        # The auto lines of managed interfaces come from the generated configuration only
        my @names = grep { !$seen_auto{"$item->{keyword} $_"}++ } @{$item->{names}};
        my @comments = @{$item->{comments} // []};
        if (@comments && $has_stanza{$item->{names}[0]}) {
            push @{$stanza_comments{$item->{names}[0]}}, @comments;
            @comments = ();
        }
        if (!grep { $_ eq $item } @$new) {
            @names = grep { !$managed{$_} && !$removed{$_} } @names;
        }
        push @out, @comments, join(' ', $item->{keyword}, @names) if @names;
    }

    for my $item (@$new) {
        next unless $item->{type} eq 'iface';
        my @options = @{$item->{options}};
        my %set = map { ((split /\s+/, $_)[0] => 1) } @options;
        my $header = $item->{header};
        my @comments = @{delete $stanza_comments{$item->{name}} // []};
        if (my $previous = $old_iface{"$item->{name} $item->{family}"}) {
            # No address from PacketFence: keep how the interface was configured (ex: dhcp)
            $header = $previous->{header} if $item->{method} eq 'manual' && $previous->{method} ne 'static';
            push @comments, @{$previous->{comments} // []};
            for my $option (@{$previous->{options}}) {
                my ($key) = split /\s+/, $option;
                next if $MANAGED_OPTIONS{$key} || $set{$key};
                push @options, $option;
            }
        }
        push @out, '', @comments, $header, map { "    $_" } @options;
    }

    for my $item (@$old[$leading .. $#$old]) {
        if ($item->{type} eq 'comment') {
            push @out, '', @{$item->{comments}}, '';
            next;
        }
        next unless $keep_old->($item);
        my @comments = (@{delete $stanza_comments{$item->{name} // ''} // []}, @{$item->{comments} // []});
        if ($item->{type} eq 'other') {
            push @out, @comments, $item->{line};
            next;
        }
        push @out, '', @comments, $item->{header}, map { "    $_" } @{$item->{options}};
    }
    return join("\n", @out) . "\n";
}

=head2 interfaces_in_sourced_files

The interfaces defined by the files that an /etc/network/interfaces content
includes (source and source-directory), as name => file. Relative paths are
relative to $base_dir, as for ifupdown.

=cut

sub interfaces_in_sourced_files {
    my ($content, $base_dir) = @_;
    my %found;
    for my $item (grep { $_->{type} eq 'source' } @{parse_interfaces_config($content)}) {
        my ($keyword, $path) = split /\s+/, $item->{line}, 2;
        next unless defined $path && length $path;
        $path = "$base_dir$path" if $path !~ m{^/};
        my @files = $keyword eq 'source'
            ? grep { -f } glob($path)
            : grep { -f && m{/[a-zA-Z0-9_-]+$} } glob("$path/*");
        for my $file (@files) {
            open(my $fh, '<', $file) or next;
            local $/;
            my $sourced = <$fh> // '';
            close($fh);
            for my $iface (grep { $_->{type} eq 'iface' } @{parse_interfaces_config($sourced)}) {
                $found{$iface->{name}} //= $file;
            }
        }
    }
    return \%found;
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
