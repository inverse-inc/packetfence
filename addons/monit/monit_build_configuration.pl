#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
    use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
}

use File::Copy;
use File::Spec::Functions;
use Template;
use List::MoreUtils qw(any);
use pf::config qw(%Config);

my $PF_PATH                                 = $pf::file_paths::install_dir;
my $MONIT_CHECKS_CONF_TEMPLATES_PATH        = catfile($PF_PATH,"addons/monit/monit_checks_configurations");
my $MONIT_CONF_TEMPLATES_PATH               = catfile($PF_PATH,"addons/monit/monit_configurations");
my $CONF_FILE_EXTENSION                     = ".conf";
my $TEMPLATE_FILE_EXTENSION                 = ".tt";
my $BACKUP_FILE_EXTENSION                   = ".bak";
my $MONIT_LOG_FILE                          = "/var/log/monit";

my %CONFIGURATION_TO_TEMPLATE   = (
    'packetfence'       => '00_packetfence',
    'portsec'           => '10_packetfence-portsec',
    'drbd'              => '20_packetfence-drbd',
    'active-active'     => '30_packetfence-activeactive',
    'os-checks'         => '50_OS-checks',
);

my $OS = ( -e "/etc/debian_version" ) ? "debian" : "rhel";
my $MONIT_PATH  = ( $OS eq "rhel" ) ? "/etc/monit.d" : "/etc/monit/conf.d";
my $MONIT_EXTRA_PATH = "$MONIT_PATH/packetfence";


if ( $#ARGV eq "-1" ) {
    print "Usage: ./monit_configuration_builder.pl 'email(s)' 'subject' 'configurations' 'mailserver' 'sender email'\n\n";
    print "email(s): List of alerting email address(es) (comma-separated if more than one)\n";
    print "subject: Identifier for email alerts\n";
    print "configurations: List of configuration to generate (comma-separated if more than one)\n";
    print "  - packetfence: Everything related to basic PacketFence\n";
    print "  - portsec: Will add some checks for port-security related services\n";
    print "  - drbd: Will add some checks for DRBD\n";
    print "  - active-active: Will add some checks for active-active clustering related services\n";
    print "  - os-checks: Will add some OS best-practices checks\n";
    print "mailserver: IP or resolvable FQDN of the mail server to use to send alerts (optional)\n";
    die "\n";
}

my ( $emails, $subject_identifier, $configurations, $mailserver, $sender ) = @ARGV;
die "No alerting email address(es) specified\n" if !defined $emails;
die "No alerting subject specified\n" if !defined $subject_identifier;
die "No configuration(s) specified\n" if !defined $configurations;
$mailserver = "localhost" if !defined $mailserver;
$sender = 'monit@$HOST' if !defined $sender;


my @emails = split(/\,/, $emails);
my @configurations = split(/\,/, $configurations);

foreach my $configuration ( @configurations ) {
    die "Invalid configuration parameter '$configuration'\n" if !exists $CONFIGURATION_TO_TEMPLATE{$configuration};
}


print "\nHere it goes!\n";
mkdir $MONIT_EXTRA_PATH unless -d $MONIT_EXTRA_PATH;
generate_monit_configurations();
generate_specific_configurations();
print "\n\nAll set!\n\n";


=head2 generate_monit_configurations

Generate Monit specific configuration files based of templates (Monit general configuration, syslog modifications for Monit)

Will also take care of backing up existing file (.bak) before overwritting

=cut

sub generate_monit_configurations {
    my $vars = {
        MONIT_LOG_FILE      => $MONIT_LOG_FILE,
        EMAILS              => \@emails,
        SUBJECT_IDENTIFIER  => $subject_identifier,
        MAILSERVER          => $mailserver,
        ALERTING_CONF       => $Config{alerting},
        SENDER              => $sender,
    };
    my $tt = Template->new(ABSOLUTE => 1);
    my $template_file;
    my $destination_file;

    # Monit general configuration
    $template_file = catfile($MONIT_CONF_TEMPLATES_PATH, "monit_general" . $TEMPLATE_FILE_EXTENSION);
    $destination_file = catfile($MONIT_PATH, "monit_general" . $CONF_FILE_EXTENSION);
    print "Generating '$destination_file'\n";
    $tt->process($template_file, $vars, $destination_file) or die $tt->error();
    print "\n/!\\ -> Applied 'Monit' configuration. You might want to restart it for the change to take place\n\n";

    # Syslog configuration
    $template_file = catfile($MONIT_CONF_TEMPLATES_PATH, "syslog_monit" . $TEMPLATE_FILE_EXTENSION);
    $destination_file = "/etc/rsyslog.d/monit.conf";
    print "Generating '$destination_file'\n";
    $tt->process($template_file, $vars, $destination_file) or die $tt->error();
    unlink "$MONIT_PATH/logging"; # Remove default Monit logging configuration file
    system("/bin/systemctl restart rsyslog");
    print "\n/!\\ -> Applied 'rsyslog' configuration and restarted it for the new configuration to take place.\n\n";
}


=head2 generate_specific_configurations

Generate specific configuration files based of templates for specified checks

Will output XX_name.conf files under the Monit configuration directory

Will also take care of backing up existing file (XX_name.conf.bak) before overwriting

=cut

sub generate_specific_configurations {
    print "Generating the following configuration files:\n";

    my $fingerbank_enabled = (`systemctl is-enabled packetfence-fingerbank-collector` eq "enabled\n");
        
    for my $template (values (%CONFIGURATION_TO_TEMPLATE)) {
        unlink catfile($MONIT_PATH,$template . $CONF_FILE_EXTENSION);
    }

    foreach my $configuration ( @configurations ) {
        my $template_file = catfile($MONIT_CHECKS_CONF_TEMPLATES_PATH,$CONFIGURATION_TO_TEMPLATE{$configuration} . $TEMPLATE_FILE_EXTENSION);
        my $destination_file = catfile($MONIT_PATH,$CONFIGURATION_TO_TEMPLATE{$configuration} . $CONF_FILE_EXTENSION);
        print " - $destination_file\n";


        my $tt = Template->new(ABSOLUTE => 1);
        my $freeradius_bin = ( $OS eq "rhel" ) ? "radiusd" : "freeradius";
        my $mail_bin = ( $OS eq "rhel" ) ? "/bin/mail" : "/usr/bin/mail";
        my $service_bin = ( $OS eq "rhel" ) ? "/sbin/service" : "/usr/sbin/service";
        my $vars = {
            FREERADIUS_BIN      => $freeradius_bin,
            EMAILS              => \@emails,
            SUBJECT_IDENTIFIER  => $subject_identifier,
            MAILSERVER          => $mailserver,
            MAIL_BIN            => $mail_bin,
            SERVICE_BIN         => $service_bin,
            ACTIVE_ACTIVE       => (any { $_ eq 'active-active' } @configurations),
            FINGERBANK_ENABLED  => $fingerbank_enabled,
        };
        $tt->process($template_file, $vars, $destination_file) or die $tt->error();
    }
}




1;
