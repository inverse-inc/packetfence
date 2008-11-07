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


use pf::config;

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
    my %SwitchConfig = %{$this->{_config}};
    my $type = "pf::SNMP::" . ($SwitchConfig{$requestedSwitch}{'type'} || $SwitchConfig{'default'}{'type'});
    eval "require $type;";
    if ($@) {
        $logger->error("ERROR ! Unknown switch type: $type for switch $requestedSwitch: $@");
        return 0;
    }
    my @uplink = ();
    if ($SwitchConfig{$requestedSwitch}{'uplink'} || $SwitchConfig{'default'}{'uplink'}) {

        my @_uplink_tmp = split (/,/, ($SwitchConfig{$requestedSwitch}{'uplink'} || $SwitchConfig{'default'}{'uplink'}));
        foreach my $_tmp (@_uplink_tmp) {
            $_tmp =~ s/ //g;
            push @uplink, $_tmp;
        }
    }
    my @vlans = ();
    my @_vlans_tmp = split (/,/, ($SwitchConfig{$requestedSwitch}{'vlans'} || $SwitchConfig{'default'}{'vlans'}));
    foreach my $_tmp (@_vlans_tmp) {
        $_tmp =~ s/ //g;
        push @vlans, $_tmp;
    }
    $logger->debug("creating new $type object");
    return $type->new(
        '-communityRead' => ($SwitchConfig{$requestedSwitch}{'communityRead'} || $SwitchConfig{'default'}{'communityRead'}),
        '-communityWrite' => ($SwitchConfig{$requestedSwitch}{'communityWrite'} || $SwitchConfig{'default'}{'communityWrite'}), 
        '-dbHostname' => $Config{'database'}{'host'},
        '-dbName' => $Config{'database'}{'db'},
        '-dbPassword' => $Config{'database'}{'pass'},
        '-dbUser' => $Config{'database'}{'user'},
        '-htaccessPwd' => ($SwitchConfig{$requestedSwitch}{'htaccessPwd'} || $SwitchConfig{'default'}{'htaccessPwd'}),
        '-htaccessUser' => ($SwitchConfig{$requestedSwitch}{'htaccessUser'} || $SwitchConfig{'default'}{'htaccessUser'}),
        '-ip' => $SwitchConfig{$requestedSwitch}{'ip'},
        '-isolationVlan' => ($SwitchConfig{$requestedSwitch}{'isolationVlan'} || $SwitchConfig{'default'}{'isolationVlan'}), 
        '-macDetectionVlan' => ($SwitchConfig{$requestedSwitch}{'macDetectionVlan'} || $SwitchConfig{'default'}{'macDetectionVlan'}), 
	'-macSearchesMaxNb' => ($SwitchConfig{$requestedSwitch}{'macSearchesMaxNb'} || $SwitchConfig{'default'}{'macSearchesMaxNb'}),
	'-macSearchesSleepInterval' => ($SwitchConfig{$requestedSwitch}{'macSearchesSleepInterval'} || $SwitchConfig{'default'}{'macSearchesSleepInterval'}),
        '-mode' => lc(($SwitchConfig{$requestedSwitch}{'mode'} || $SwitchConfig{'default'}{'mode'})),
        '-normalVlan' => ($SwitchConfig{$requestedSwitch}{'normalVlan'} || $SwitchConfig{'default'}{'normalVlan'}), 
        '-registrationVlan' => ($SwitchConfig{$requestedSwitch}{'registrationVlan'} || $SwitchConfig{'default'}{'registrationVlan'}), 
        '-SNMPAuthPasswordRead' => ($SwitchConfig{$requestedSwitch}{'SNMPAuthPasswordRead'} || $SwitchConfig{'default'}{'SNMPAuthPasswordRead'}), 
        '-SNMPAuthPasswordWrite' => ($SwitchConfig{$requestedSwitch}{'SNMPAuthPasswordWrite'} || $SwitchConfig{'default'}{'SNMPAuthPasswordWrite'}), 
        '-SNMPAuthProtocolRead' => ($SwitchConfig{$requestedSwitch}{'SNMPAuthProtocolRead'} || $SwitchConfig{'default'}{'SNMPAuthProtocolRead'}), 
        '-SNMPAuthProtocolWrite' => ($SwitchConfig{$requestedSwitch}{'SNMPAuthProtocolWrite'} || $SwitchConfig{'default'}{'SNMPAuthProtocolWrite'}), 
        '-SNMPPrivPasswordRead' => ($SwitchConfig{$requestedSwitch}{'SNMPPrivPasswordRead'} || $SwitchConfig{'default'}{'SNMPPrivPasswordRead'}), 
        '-SNMPPrivPasswordWrite' => ($SwitchConfig{$requestedSwitch}{'SNMPPrivPasswordWrite'} || $SwitchConfig{'default'}{'SNMPPrivPasswordWrite'}), 
        '-SNMPPrivProtocolRead' => ($SwitchConfig{$requestedSwitch}{'SNMPPrivProtocolRead'} || $SwitchConfig{'default'}{'SNMPPrivProtocolRead'}), 
        '-SNMPPrivProtocolWrite' => ($SwitchConfig{$requestedSwitch}{'SNMPPrivProtocolWrite'} || $SwitchConfig{'default'}{'SNMPPrivProtocolWrite'}), 
        '-SNMPUserNameRead' => ($SwitchConfig{$requestedSwitch}{'SNMPUserNameRead'} || $SwitchConfig{'default'}{'SNMPUserNameRead'}), 
        '-SNMPUserNameWrite' => ($SwitchConfig{$requestedSwitch}{'SNMPUserNameWrite'} || $SwitchConfig{'default'}{'SNMPUserNameWrite'}), 
        '-cliEnablePwd' => ($SwitchConfig{$requestedSwitch}{'cliEnablePwd'} || $SwitchConfig{$requestedSwitch}{'telnetEnablePwd'} || $SwitchConfig{'default'}{'cliEnablePwd'} || $SwitchConfig{'default'}{'telnetEnablePwd'}),
        '-cliPwd' => ($SwitchConfig{$requestedSwitch}{'cliPwd'} || $SwitchConfig{$requestedSwitch}{'telnetPwd'} || $SwitchConfig{'default'}{'cliPwd'} || $SwitchConfig{'default'}{'telnetPwd'}),
        '-cliUser' => ($SwitchConfig{$requestedSwitch}{'cliUser'} || $SwitchConfig{$requestedSwitch}{'telnetUser'} || $SwitchConfig{'default'}{'cliUser'} || $SwitchConfig{'default'}{'telnetUser'}),
        '-cliTransport' => ($SwitchConfig{$requestedSwitch}{'cliTransport'} || $SwitchConfig{'default'}{'cliTransport'} || 'Telnet'),
        '-uplink' => \@uplink,
        '-version' => ($SwitchConfig{$requestedSwitch}{'version'} || $SwitchConfig{'default'}{'version'}),
        '-vlans' => \@vlans,
        '-voiceVlan' => ($SwitchConfig{$requestedSwitch}{'voiceVlan'} || $SwitchConfig{'default'}{'voiceVlan'}), 
        '-VoIPEnabled' => (($SwitchConfig{$requestedSwitch}{'VoIPEnabled'} || $SwitchConfig{'default'}{'VoIPEnabled'}) =~ /^\s*(y|yes|true|enabled|1)\s*$/i ? 1 : 0)
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
    my %SwitchConfig;
    if (! -e $this->{_configFile}) {
        croak "Config file " . $this->{_configFile} . " cannot be read\n";
    }
    tie %SwitchConfig, 'Config::IniFiles', ( -file => $this->{_configFile});
    my @errors = @Config::IniFiles::errors;
    if (scalar(@errors)) {
        croak "Error reading config file: " . join("\n", @errors) . "\n";
    }

    #remove trailing spaces..
    foreach my $section (tied(%SwitchConfig)->Sections){
        foreach my $key (keys %{$SwitchConfig{$section}}){
            $SwitchConfig{$section}{$key}=~s/\s+$//;
        }
    }
    %{$this->{_config}} = %SwitchConfig;

    return 1;
}

=back

=cut

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
