#
# Copyright 2006-2008 Inverse groupe conseil
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html
#
#

package pf::SwitchFactory;

=head1 NAME

pf::SwitchFactory - Object oriented factory to instantiate objects


=head1 SYNOPSIS

The pf::SwitchFactory module implements an object oriented factory to
instantiate objects of type pf::SNMP or subclasses of this. This module
is meant to read in a switches.conf configuration file containing all
the necessary information needed to actually instantiate the objects.

=cut

use strict;
use warnings;
use diagnostics;

use Carp;
use Config::IniFiles;
use Log::Log4perl;


use lib "/usr/local/pf/lib";

=head1 METHODS

=over

=cut

sub new {
    my $logger = Log::Log4perl::get_logger("pf::SwitchFactory");
    $logger->debug("instantiating new SwitchFactory object");
    my ($class, %argv) = @_;
    my $this = bless {
        '_configFile' => undef,
        '_config' => undef
    }, $class;

    foreach (keys %argv) {
        if (/^-?configFile$/i) {
            $this->{_configFile} = $argv{$_};
        }
    }

    if (defined($this->{_configFile})) {
        $this->readConfig();
    }

    return $this;
}

=item instantiate - create new pf::SNMP (or subclass) object

  $switch = SwitchFactory->instantiate( <switchIdentifier> );

=cut
sub instantiate {
    my $logger = Log::Log4perl::get_logger("pf::SwitchFactory");
    my ($this, $requestedSwitch) = @_;
    my %Config = %{$this->{_config}};
    my $type = "pf::SNMP::" . ($Config{$requestedSwitch}{'type'} || $Config{'default'}{'type'});
    eval "require $type;";
    if ($@) {
        $logger->error("ERROR ! Unknown switch type: " . $Config{$requestedSwitch}{'type'} . " for switch $requestedSwitch: $@");
        return 0;
    }
    my @uplink = ();
    if ($Config{$requestedSwitch}{'uplink'} || $Config{'default'}{'uplink'}) {

        my @_uplink_tmp = split (/,/, ($Config{$requestedSwitch}{'uplink'} || $Config{'default'}{'uplink'}));
        foreach my $_tmp (@_uplink_tmp) {
            $_tmp =~ s/ //g;
            push @uplink, $_tmp;
        }
    }
    my @vlans = ();
    my @_vlans_tmp = split (/,/, ($Config{$requestedSwitch}{'vlans'} || $Config{'default'}{'vlans'}));
    foreach my $_tmp (@_vlans_tmp) {
        $_tmp =~ s/ //g;
        push @vlans, $_tmp;
    }
    $logger->debug("creating new $type object");
    return $type->new(
        '-communityRead' => ($Config{$requestedSwitch}{'communityRead'} || $Config{'default'}{'communityRead'}),
        '-communityWrite' => ($Config{$requestedSwitch}{'communityWrite'} || $Config{'default'}{'communityWrite'}), 
        '-dbHostname' => $Config{'default'}{'database_hostname'},
        '-dbName' => $Config{'default'}{'database_dbname'},
        '-dbPassword' => $Config{'default'}{'database_password'},
        '-dbUser' => $Config{'default'}{'database_user'},
        '-htaccessPwd' => ($Config{$requestedSwitch}{'htaccessPwd'} || $Config{'default'}{'htaccessPwd'}),
        '-htaccessUser' => ($Config{$requestedSwitch}{'htaccessUser'} || $Config{'default'}{'htaccessUser'}),
        '-ip' => $Config{$requestedSwitch}{'ip'},
        '-isolationVlan' => ($Config{$requestedSwitch}{'isolationVlan'} || $Config{'default'}{'isolationVlan'}), 
        '-macDetectionVlan' => ($Config{$requestedSwitch}{'macDetectionVlan'} || $Config{'default'}{'macDetectionVlan'}), 
	'-macSearchesMaxNb' => ($Config{$requestedSwitch}{'macSearchesMaxNb'} || $Config{'default'}{'macSearchesMaxNb'}),
	'-macSearchesSleepInterval' => ($Config{$requestedSwitch}{'macSearchesSleepInterval'} || $Config{'default'}{'macSearchesSleepInterval'}),
        '-mode' => lc(($Config{$requestedSwitch}{'mode'} || $Config{'default'}{'mode'})),
        '-normalVlan' => ($Config{$requestedSwitch}{'normalVlan'} || $Config{'default'}{'normalVlan'}), 
        '-registrationVlan' => ($Config{$requestedSwitch}{'registrationVlan'} || $Config{'default'}{'registrationVlan'}), 
        '-SNMPAuthPasswordRead' => ($Config{$requestedSwitch}{'SNMPAuthPasswordRead'} || $Config{'default'}{'SNMPAuthPasswordRead'}), 
        '-SNMPAuthPasswordWrite' => ($Config{$requestedSwitch}{'SNMPAuthPasswordWrite'} || $Config{'default'}{'SNMPAuthPasswordWrite'}), 
        '-SNMPAuthProtocolRead' => ($Config{$requestedSwitch}{'SNMPAuthProtocolRead'} || $Config{'default'}{'SNMPAuthProtocolRead'}), 
        '-SNMPAuthProtocolWrite' => ($Config{$requestedSwitch}{'SNMPAuthProtocolWrite'} || $Config{'default'}{'SNMPAuthProtocolWrite'}), 
        '-SNMPPrivPasswordRead' => ($Config{$requestedSwitch}{'SNMPPrivPasswordRead'} || $Config{'default'}{'SNMPPrivPasswordRead'}), 
        '-SNMPPrivPasswordWrite' => ($Config{$requestedSwitch}{'SNMPPrivPasswordWrite'} || $Config{'default'}{'SNMPPrivPasswordWrite'}), 
        '-SNMPPrivProtocolRead' => ($Config{$requestedSwitch}{'SNMPPrivProtocolRead'} || $Config{'default'}{'SNMPPrivProtocolRead'}), 
        '-SNMPPrivProtocolWrite' => ($Config{$requestedSwitch}{'SNMPPrivProtocolWrite'} || $Config{'default'}{'SNMPPrivProtocolWrite'}), 
        '-SNMPUserNameRead' => ($Config{$requestedSwitch}{'SNMPUserNameRead'} || $Config{'default'}{'SNMPUserNameRead'}), 
        '-SNMPUserNameWrite' => ($Config{$requestedSwitch}{'SNMPUserNameWrite'} || $Config{'default'}{'SNMPUserNameWrite'}), 
        '-cliEnablePwd' => ($Config{$requestedSwitch}{'cliEnablePwd'} || $Config{$requestedSwitch}{'telnetEnablePwd'} || $Config{'default'}{'cliEnablePwd'} || $Config{'default'}{'telnetEnablePwd'}),
        '-cliPwd' => ($Config{$requestedSwitch}{'cliPwd'} || $Config{$requestedSwitch}{'telnetPwd'} || $Config{'default'}{'cliPwd'} || $Config{'default'}{'telnetPwd'}),
        '-cliUser' => ($Config{$requestedSwitch}{'cliUser'} || $Config{$requestedSwitch}{'telnetUser'} || $Config{'default'}{'cliUser'} || $Config{'default'}{'telnetUser'}),
        '-cliTransport' => ($Config{$requestedSwitch}{'cliTransport'} || $Config{'default'}{'cliTransport'} || 'Telnet'),
        '-uplink' => \@uplink,
        '-version' => ($Config{$requestedSwitch}{'version'} || $Config{'default'}{'version'}),
        '-vlans' => \@vlans,
        '-voiceVlan' => ($Config{$requestedSwitch}{'voiceVlan'} || $Config{'default'}{'voiceVlan'}), 
        '-VoIPEnabled' => (($Config{$requestedSwitch}{'VoIPEnabled'} || $Config{'default'}{'VoIPEnabled'}) =~ /^\s*(y|yes|true|enabled|1)\s*$/i ? 1 : 0)
    );
}


=item readConfig - read configuration file

  $switchFactory->readConfig();

=cut

sub readConfig {
    my $this = shift;
    my $logger = Log::Log4perl::get_logger("pf::SwitchFactory");
    $logger->debug("reading config file $this->{_configFile}");
    if (! defined($this->{_configFile})) {
        croak "Config file has not been defined\n";
    }
    my %Config;
    if (! -e $this->{_configFile}) {
        croak "Config file " . $this->{_configFile} . " cannot be read\n";
    }
    tie %Config, 'Config::IniFiles', ( -file => $this->{_configFile});
    my @errors = @Config::IniFiles::errors;
    if (scalar(@errors)) {
        croak "Error reading config file: " . join("\n", @errors) . "\n";
    }

    #remove trailing spaces..
    foreach my $section (tied(%Config)->Sections){
        foreach my $key (keys %{$Config{$section}}){
            $Config{$section}{$key}=~s/\s+$//;
        }
    }
    %{$this->{_config}} = %Config;

    return 1;
}

=back

=cut

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
