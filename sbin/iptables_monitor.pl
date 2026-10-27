#!/usr/bin/perl
use strict;
use warnings;

use lib '/usr/local/pf/lib';
use lib '/usr/local/pf/lib_perl/lib/perl5';

use pf::file_paths qw($generated_iptables_conf_dir $conf_dir);
use pf::log;
use pf::iptables qw(iptables_generate_config);
use pf::config qw($management_network %Config);
use pf::util qw(isenabled);
use Linux::Inotify2;

# Keep in sync with SuccessExitStatus/RestartPreventExitStatus in the unit.
use constant EXIT_MANAGEMENT_UNSET => 78;

my $inotify = new Linux::Inotify2 or die "Unable to create inotify object: $!";

my $managed = is_management_network_set();

sub is_management_network_set {
    if (ref($management_network) && exists $management_network->{Tint} ) {
        my $tint = $management_network->{Tint};
        if ( $tint ne "" ) {
            return 1;
        }
    }
    return 0;
}

sub generate_iptables_configuration {
    my ( $file ) = @_;
    my $logger = get_logger();
    if ( is_management_network_set() ) {
        $logger->info("File $file was modified at ".localtime().".");
        iptables_generate_config();
    } else {
        $logger->warn("Service Iptables: Management interface is not set.");
    }
}

# services.iptables is disabled: stay up without touching iptables (the
# services that want packetfence-iptables would otherwise restart it in a
# loop) and start managing the rules once it is enabled again
my $was_disabled = 0;
unless ( pf::iptables::iptables_is_managed() ) {
    $was_disabled = 1;
    sleep(30) until isenabled($Config{'services'}{'iptables'});
    get_logger->info("services.iptables was enabled, PacketFence manages iptables again");
}

if ( $managed ) {
    my $logger = get_logger();
    $logger->info("Service Iptables: Management interface is waiting.");
    $inotify->watch( $generated_iptables_conf_dir, IN_CREATE | IN_DELETE | IN_MODIFY | IN_CLOSE_WRITE, sub {
        my $event = shift;
        my $file = $event->fullname;
        generate_iptables_configuration($file);
    });
    $inotify->watch( $conf_dir."/iptables-custom.conf.inc", IN_CREATE | IN_DELETE | IN_MODIFY | IN_CLOSE_WRITE, sub {
        my $event = shift;
        my $file = $event->fullname;
        generate_iptables_configuration($file);
    });
    # The rules files were written while iptables wasn't managed, apply them now
    generate_iptables_configuration("services.iptables") if $was_disabled;
}

while ( $managed ) {
    $inotify->poll;
    $managed = is_management_network_set();
}

get_logger()->info("Service Iptables: Management interface is not set; stopping until the next service start.");
exit EXIT_MANAGEMENT_UNSET;
