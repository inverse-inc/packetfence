#!/usr/bin/perl
use strict;
use warnings;

use lib '/usr/local/pf/lib';
use lib '/usr/local/pf/lib_perl/lib/perl5';

use pf::file_paths qw($generated_ip6tables_conf_dir $conf_dir);
use pf::log;
use pf::ip6tables qw(ip6tables_generate_config);
use pf::config qw($management_network);
use File::Path qw(make_path);
use Linux::Inotify2;

my $inotify = new Linux::Inotify2 or die "Unable to create inotify object: $!";
my $logger = get_logger();

sub is_management_network_set {
    # Check if IPv4 management interface exists
    if (ref($management_network) && exists $management_network->{Tint} ) {
        my $tint = $management_network->{Tint};
        if ( $tint ne "" ) {
            return 1;
        }
    }
    return 0;
}

sub is_ipv6_management_network_set {
    # Check if IPv6 is configured on management interface
    if (ref($management_network) && exists $management_network->{Tint} ) {
        my $tint = $management_network->{Tint};
        if ( $tint ne "" ) {
            my $ipv6_address = $management_network->tag("ipv6_address");
            my $ipv6_prefix = $management_network->tag("ipv6_prefix");
            if ( defined($ipv6_address) && $ipv6_address ne "" &&
                 defined($ipv6_prefix) && $ipv6_prefix ne "" ) {
                return 1;
            }
        }
    }
    return 0;
}

sub is_any_management_network_set {
    # Service should run if IPv4 OR IPv6 management is configured
    return is_management_network_set() || is_ipv6_management_network_set();
}

my $ipv6_managed = is_ipv6_management_network_set();
my $any_managed = is_any_management_network_set();

# Log IPv6 status
if ( $ipv6_managed ) {
    $logger->info("Service Ip6tables: IPv6 configured on management interface.");
} else {
    $logger->info("Service Ip6tables: IPv6 not configured on management interface.");
}

sub generate_ip6tables_configuration {
    my ( $file ) = @_;
    if ( is_any_management_network_set() ) {
        $logger->info("File $file was modified at ".localtime().".");
        ip6tables_generate_config();
    } else {
        $logger->warn("Service Ip6tables: Management network no longer available.");
    }
}

if ( $any_managed ) {
    $logger->info("Service Ip6tables: Starting monitoring.");
    make_path($generated_ip6tables_conf_dir) unless -d $generated_ip6tables_conf_dir;
    $inotify->watch( $generated_ip6tables_conf_dir, IN_CREATE | IN_DELETE | IN_MODIFY | IN_CLOSE_WRITE, sub {
        my $event = shift;
        my $file = $event->fullname;
        generate_ip6tables_configuration($file);
    }) or $logger->error("Could not watch $generated_ip6tables_conf_dir: $!");
    $inotify->watch( $conf_dir."/ip6tables-custom.conf.inc", IN_CREATE | IN_DELETE | IN_MODIFY | IN_CLOSE_WRITE, sub {
        my $event = shift;
        my $file = $event->fullname;
        generate_ip6tables_configuration($file);
    });
}

while ( $any_managed ) {
    $inotify->poll;
    $any_managed = is_any_management_network_set();
}
