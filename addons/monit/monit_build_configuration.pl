#!/usr/bin/perl

use strict;
use warnings;

use File::Copy;
use Template;

BEGIN {
    use lib "/usr/local/pf/lib";
}

my $PF_PATH                     = $pf::file_paths::install_dir;
my $MONIT_PATH                  = "/etc/monit.d/";
my $CONF_FILE_EXTENSION         = ".conf";
my $TEMPLATE_FILE_EXTENSION     = ".tt";
my $FREERADIUS_BIN = ( -e "/etc/debian_version" ) ? "freeradius" : "radiusd";
my %CONFIGURATION_TO_TEMPLATE   = (
    'packetfence'     => '00_packetfence',
    'portsec'         => '10_packetfence-portsec',
    'drbd'            => '20_packetfence-drbd',
    'active-active'   => '30_packetfence-activeactive',
    'os-winbind'      => '40_OS-winbind',
);
my $MONIT_LOG_FILE = "/var/log/monit";

if ( $#ARGV eq "-1" ) {
    print "Usage: ./monit_configuration_builder.pl 'email(s)' 'subject' 'configurations'\n\n";
    print "email(s): List of alerting email address(es) (comma-separated if more than one)\n";
    print "subject: Identifier for email alerts\n";
    print "configurations: List of configuration to generate (comma-separated if more than one)\n";
    print "  - packetfence: Everything related to basic PacketFence\n";
    print "  - portsec: Will add some checks for port-security related services\n";
    print "  - drbd: Will add some checks for DRBD\n";
    print "  - active-active: Will add some checks for active-active clustering related services\n";
    print "  - os-winbind: Will add a check for the operating system winbindd process. Use it when the winbind/samba configuration is made outside PacketFence.\n";
    die "\n";
}

my ( $emails, $subject_identifier, $configurations ) = @ARGV;
die "No alerting email address(es) specified\n" if !defined $emails;
die "No alerting subject specified\n" if !defined $subject_identifier;
die "No configuration(s) specified\n" if !defined $configurations;


my @emails = split(/\,/, $emails);
my @configurations = split(/\,/, $configurations);

foreach my $configuration ( @configurations ) {
    die "Invalid configuration parameter '$configuration'\n" if !exists $CONFIGURATION_TO_TEMPLATE{$configuration};
}


generate_configurations();
monit_syslog_configuration();


sub generate_configurations {
    print "\n\nGenerating the following configuration files: \n";

    foreach my $configuration ( @configurations ) {
        my $template_file = $PF_PATH . "/addons/monit/" . $CONFIGURATION_TO_TEMPLATE{$configuration} . $TEMPLATE_FILE_EXTENSION;
        my $destination_file = $MONIT_PATH . $CONFIGURATION_TO_TEMPLATE{$configuration} . $CONF_FILE_EXTENSION;
        print " - $destination_file\n";

        # Backing up existing configuration file (just in case)
        move($destination_file, $destination_file . ".bak") if -e $destination_file;

        # Handling pfdhcplisteners
        my $pfdhcplisteners = handle_pfdhcplisteners();
        # Handling domains (winbind configuration)
        my $domains = handle_domains();

        my $tt = Template->new(ABSOLUTE => 1);
        my $vars = {
            FREERADIUS_BIN      => $FREERADIUS_BIN,
            EMAILS              => \@emails,
            SUBJECT_IDENTIFIER  => $subject_identifier,
            PFDHCPLISTENERS     => $pfdhcplisteners,
            DOMAINS             => $domains,
        };
        $tt->process($template_file, $vars, $destination_file) or die $tt->error();
    }

    print "\n\nAll set!";
}


sub handle_pfdhcplisteners {
    use pf::services::manager::pfdhcplistener;
    my $self = pf::services::manager::pfdhcplistener->new(name => 'dummy');
    my @managers = $self->pf::services::manager::pfdhcplistener::managers;
    my @pfdhcplisteners = ();
    push @pfdhcplisteners, $_->{name} foreach ( @managers );
    return \@pfdhcplisteners;
}

sub handle_domains {
    use pf::config;
    use pf::services::manager::winbindd_child;
    my %domains = ();
    foreach my $domain ( keys(%pf::config::ConfigDomain) ) {
        $domains{$domain} = pf::services::manager::winbindd_child->new(name => 'dummy', domain => "$domain")->pidFile;
    }
    return \%domains;
}

sub monit_syslog_configuration {
    # Generate syslog Monit configuration file
    my $tt = Template->new(ABSOLUTE => 1);
    my $vars = {
        MONIT_LOG_FILE  => $MONIT_LOG_FILE,
    };
    $tt->process($PF_PATH . "/addons/monit/" . "syslog_monit" . $TEMPLATE_FILE_EXTENSION, $vars, "/etc/rsyslog.d/monit.conf") or die $tt->error();

    # Remove default Monit logging configuration file
    unlink '/etc/monit.d/logging';
}

1;
