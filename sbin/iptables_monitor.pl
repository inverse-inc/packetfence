#!/usr/bin/perl
use strict;
use warnings;

use lib '/usr/local/pf/lib';
use lib '/usr/local/pf/lib_perl/lib/perl5';

use pf::file_paths qw($generated_iptables_conf_dir);
use pf::log;
use pf::iptables qw(iptables_generate_config);
use pf::config qw($management_network);
use Linux::Inotify2;

my $inotify = new Linux::Inotify2 or die "Unable to create inotify object: $!";

my $managed = is_management_network_set();

sub is_management_network_set {
    if (ref($management_network) && exists $management_network->{Tint} ) {
        my $tint = $management_network->{Tint};
        if ( $tint ne "" ) {
            return 1;
        }
    }
    return 0
}

if ( $managed ) {
    $inotify->watch( $generated_iptables_conf_dir, IN_MODIFY | IN_CLOSE_WRITE, sub {
        my $event = shift;
        my $file = $event->fullname;
        my $logger = get_logger();
    
        if (ref($management_network) && exists $management_network->{Tint} ) {
            my $tint = $management_network->{Tint};
            if ( $tint ne "" ) {
                $logger->info("File $file was modified at ".localtime().".");
                iptables_generate_config();
            }
        } else {
            $logger->warn("Service Iptables: Management interface is not set.");
        }
    });
}

while ( $managed ) {
    $inotify->poll;
    $managed = is_management_network_set();
}
