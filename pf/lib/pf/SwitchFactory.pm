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
        '-ip' => $Config{$requestedSwitch}{'ip'},
        '-version' => ($Config{$requestedSwitch}{'version'} || $Config{'default'}{'version'}),
        '-communityRead' => ($Config{$requestedSwitch}{'communityRead'} || $Config{'default'}{'communityRead'}),
        '-communityWrite' => ($Config{$requestedSwitch}{'communityWrite'} || $Config{'default'}{'communityWrite'}), 
        '-SNMPUserNameRead' => ($Config{$requestedSwitch}{'SNMPUserNameRead'} || $Config{'default'}{'SNMPUserNameRead'}), 
        '-SNMPAuthPasswordRead' => ($Config{$requestedSwitch}{'SNMPAuthPasswordRead'} || $Config{'default'}{'SNMPAuthPasswordRead'}), 
        '-SNMPAuthProtocolRead' => ($Config{$requestedSwitch}{'SNMPAuthProtocolRead'} || $Config{'default'}{'SNMPAuthProtocolRead'}), 
        '-SNMPPrivPasswordRead' => ($Config{$requestedSwitch}{'SNMPPrivPasswordRead'} || $Config{'default'}{'SNMPPrivPasswordRead'}), 
        '-SNMPPrivProtocolRead' => ($Config{$requestedSwitch}{'SNMPPrivProtocolRead'} || $Config{'default'}{'SNMPPrivProtocolRead'}), 
        '-SNMPUserNameWrite' => ($Config{$requestedSwitch}{'SNMPUserNameWrite'} || $Config{'default'}{'SNMPUserNameWrite'}), 
        '-SNMPAuthPasswordWrite' => ($Config{$requestedSwitch}{'SNMPAuthPasswordWrite'} || $Config{'default'}{'SNMPAuthPasswordWrite'}), 
        '-SNMPAuthProtocolWrite' => ($Config{$requestedSwitch}{'SNMPAuthProtocolWrite'} || $Config{'default'}{'SNMPAuthProtocolWrite'}), 
        '-SNMPPrivPasswordWrite' => ($Config{$requestedSwitch}{'SNMPPrivPasswordWrite'} || $Config{'default'}{'SNMPPrivPasswordWrite'}), 
        '-SNMPPrivProtocolWrite' => ($Config{$requestedSwitch}{'SNMPPrivProtocolWrite'} || $Config{'default'}{'SNMPPrivProtocolWrite'}), 
        '-normalVlan' => ($Config{$requestedSwitch}{'normalVlan'} || $Config{'default'}{'normalVlan'}), 
        '-macDetectionVlan' => ($Config{$requestedSwitch}{'macDetectionVlan'} || $Config{'default'}{'macDetectionVlan'}), 
        '-voiceVlan' => ($Config{$requestedSwitch}{'voiceVlan'} || $Config{'default'}{'voiceVlan'}), 
        '-registrationVlan' => ($Config{$requestedSwitch}{'registrationVlan'} || $Config{'default'}{'registrationVlan'}), 
        '-isolationVlan' => ($Config{$requestedSwitch}{'isolationVlan'} || $Config{'default'}{'isolationVlan'}), 
        '-uplink' => \@uplink,
        '-vlans' => \@vlans,
        '-mode' => lc(($Config{$requestedSwitch}{'mode'} || $Config{'default'}{'mode'})),
        '-telnetUser' => ($Config{$requestedSwitch}{'telnetUser'} || $Config{'default'}{'telnetUser'} || ''),
        '-telnetPwd' => ($Config{$requestedSwitch}{'telnetPwd'} || $Config{'default'}{'telnetPwd'}),
        '-telnetEnablePwd' => ($Config{$requestedSwitch}{'telnetEnablePwd'} || $Config{'default'}{'telnetEnablePwd'}),
        '-htaccessPwd' => ($Config{$requestedSwitch}{'htaccessPwd'} || $Config{'default'}{'htaccessPwd'}),
        '-htaccessUser' => ($Config{$requestedSwitch}{'htaccessUser'} || $Config{'default'}{'htaccessUser'}),
        '-dbHostname' => $Config{'default'}{'database_hostname'},
        '-dbUser' => $Config{'default'}{'database_user'},
        '-dbPassword' => $Config{'default'}{'database_password'},
        '-dbName' => $Config{'default'}{'database_dbname'},
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
