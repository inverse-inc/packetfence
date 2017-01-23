#!/usr/bin/perl

use strict;
use warnings;

use File::Copy;
use File::Spec::Functions;
use Template;

BEGIN {
    use lib "/usr/local/pf/lib";
}


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
    'os-winbind'        => '40_OS-winbind',
    'os-checks'         => '50_OS-checks',
);

my $OS = ( -e "/etc/debian_version" ) ? "debian" : "rhel";
my $MONIT_PATH  = ( $OS eq "rhel" ) ? "/etc/monit.d" : "/etc/monit/conf.d";


if ( $#ARGV eq "-1" ) {
    print "Usage: ./monit_configuration_builder.pl 'email(s)' 'subject' 'configurations'\n\n";
    print "email(s): List of alerting email address(es) (comma-separated if more than one)\n";
    print "subject: Identifier for email alerts\n";
    print "configurations: List of configuration to generate (comma-separated if more than one)\n";
    print "  - packetfence: Everything related to basic PacketFence\n";
    print "  - portsec: Will add some checks for port-security related services\n";
    print "  - drbd: Will add some checks for DRBD\n";
    print "  - active-active: Will add some checks for active-active clustering related services\n";
    print "  - os-winbind: Will add a check for the operating system winbindd process. Use it when the winbind/samba configuration is made outside PacketFence\n";
    print "  - os-checks: Will add some OS best-practices checks\n";
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


print "\nHere it goes!\n";
generate_monit_configurations();
generate_specific_configurations();
print "\n\nAll set!\n\n";


=head2 generate_monit_configurations

Generate Monit specific configuration files based of templates (Monit general configuration, syslog modifications for Monit)

Will also take care of backing up existing file (.bak) before overwritting

=cut

sub generate_monit_configurations {
    my $syslog_engine = ( $OS eq "rhel" ) ? "syslog" : "rsyslog";

    my $vars = {
        MONIT_LOG_FILE      => $MONIT_LOG_FILE,
        EMAILS              => \@emails,
        SUBJECT_IDENTIFIER  => $subject_identifier,
    };
    my $tt = Template->new(ABSOLUTE => 1);
    my $template_file;
    my $destination_file;

    # Monit general configuration
    $template_file = catfile($MONIT_CONF_TEMPLATES_PATH, "monit_general" . $TEMPLATE_FILE_EXTENSION);
    $destination_file = catfile($MONIT_PATH, "monit_general" . $CONF_FILE_EXTENSION);
    print "Generating '$destination_file'\n";
    if ( -e $destination_file ) {
        my $backup_file = $destination_file . $BACKUP_FILE_EXTENSION;
        move($destination_file, $backup_file);
        print "Generating '$backup_file' (BACKED UP FILE)\n";
    }
    $tt->process($template_file, $vars, $destination_file) or die $tt->error();
    print "\n/!\\ -> Applied Monit configuration. You might want to restart Monit for the change to take place\n\n";

    # Syslog configuration
    $template_file = catfile($MONIT_CONF_TEMPLATES_PATH, "syslog_monit" . $TEMPLATE_FILE_EXTENSION);
    $destination_file = "/etc/$syslog_engine.d/monit.conf";
    print "Generating '$destination_file'\n";
    if ( -e $destination_file ) {
        my $backup_file = catfile($MONIT_PATH, "syslog_monit" . $CONF_FILE_EXTENSION . $BACKUP_FILE_EXTENSION);
        move($destination_file, $backup_file);
        print "Generating '$backup_file' (BACKED UP FILE)\n";
    }
    $tt->process($template_file, $vars, $destination_file) or die $tt->error();
    unlink "$MONIT_PATH/logging"; # Remove default Monit logging configuration file
    print "\n/!\\ -> Applied $syslog_engine configuration. You might want to restart $syslog_engine for the change to take place\n\n";
}


=head2 generate_specific_configurations

Generate specific configuration files based of templates for specified checks

Will output XX_name.conf files under the Monit configuration directory

Will also take care of backing up existing file (XX_name.conf.bak) before overwriting

=cut

sub generate_specific_configurations {
    print "Generating the following configuration files:\n";

    foreach my $configuration ( @configurations ) {
        my $template_file = catfile($MONIT_CHECKS_CONF_TEMPLATES_PATH,$CONFIGURATION_TO_TEMPLATE{$configuration} . $TEMPLATE_FILE_EXTENSION);
        my $destination_file = catfile($MONIT_PATH,$CONFIGURATION_TO_TEMPLATE{$configuration} . $CONF_FILE_EXTENSION);
        print " - $destination_file\n";

        # Backing up existing configuration file (just in case)
        if ( -e $destination_file ) {
            move($destination_file, $destination_file . $BACKUP_FILE_EXTENSION);
            print " - $destination_file" . "$BACKUP_FILE_EXTENSION (BACKED UP FILE)\n";
        }

        # Handling pfdhcplisteners
        my $pfdhcplisteners = handle_pfdhcplisteners();
        # Handling domains (winbind configuration)
        my $domains = handle_domains();

        my $tt = Template->new(ABSOLUTE => 1);
        my $freeradius_bin = ( $OS eq "rhel" ) ? "radiusd" : "freeradius";
        my $mail_bin = ( $OS eq "rhel" ) ? "/bin/mail" : "/usr/bin/mail";
        my $service_bin = ( $OS eq "rhel" ) ? "/sbin/service" : "/usr/sbin/service";
        my $winbindd_pid = ( $OS eq "rhel" ) ? "/var/run/winbindd.pid" : "/var/run/samba/winbindd.pid";
        my $vars = {
            FREERADIUS_BIN      => $freeradius_bin,
            EMAILS              => \@emails,
            SUBJECT_IDENTIFIER  => $subject_identifier,
            PFDHCPLISTENERS     => $pfdhcplisteners,
            DOMAINS             => $domains,
            MAIL_BIN            => $mail_bin,
            SERVICE_BIN         => $service_bin,
            WINBINDD_PID        => $winbindd_pid,
        };
        $tt->process($template_file, $vars, $destination_file) or die $tt->error();
    }
}


=head2 handle_pfdhcplisteners

Generate the dhcplistener network interfaces array to be used in configuration templates

=cut

sub handle_pfdhcplisteners {
    use pf::services::manager::pfdhcplistener;
    my $self = pf::services::manager::pfdhcplistener->new(name => 'dummy');
    my @managers = $self->pf::services::manager::pfdhcplistener::managers;
    my @pfdhcplisteners = ();
    push @pfdhcplisteners, $_->{name} foreach ( @managers );
    return \@pfdhcplisteners;
}


=head2 handle_domains

Generate the managed by PacketFence domain list array to be used in configuration templates

=cut

sub handle_domains {
    use pf::config;
    use pf::services::manager::winbindd_child;
    my %domains = ();
    foreach my $domain ( keys(%pf::config::ConfigDomain) ) {
        $domains{$domain} = pf::services::manager::winbindd_child->new(name => "winbindd-$domain.conf", domain => "$domain")->pidFile;
    }
    return \%domains;
}


1;
