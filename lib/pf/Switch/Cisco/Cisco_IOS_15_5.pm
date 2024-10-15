package pf::Switch::Cisco::Cisco_IOS_15_5;

=head1 NAME

pf::Switch::Cisco::Cisco_IOS_15_5 - Object oriented module to access and configure Cisco Catalyst 2960 switches

=head1 STATUS

=head1 SUPPORTS

=head2 802.1X with or without VoIP

=head2 Port-Security with or without VoIP

=head2 Link Up / Link Down

=head2 Stacked configuration

=head2 Firmware version

Recommended firmware is 12.2(58)SE1

The absolute minimum required firmware version is 12.2(25)SEE2.

Port-security + VoIP mode works with firmware 12.2(44)SE or greater unless mentioned below.
Earlier IOS were not explicitly tested.

The RADIUS part of this module also works with IOS XE switches.
It has been tested on IOS XE version 03.07.02E

This module extends pf::Switch::Cisco::Cisco_IOS_12_x.

=head1 PRODUCT LINES

=head2 2960, 2960S, 2960G

With no limitations that we are aware of.

=head2 2960 LanLite

The LanLite series doesn't support the fallback VLAN on RADIUS AAA based
approaches (MAC-Auth, 802.1X). This can affect fail-open scenarios.

=head1 BUGS AND LIMITATIONS

=head2 Port-Security

=head2 Status with IOS 15.x

At the moment we faced regressions with the Cisco IOS 15.x series. Not a lot
of investigation was performed but at this point consider this series as
broken with a Port-Security based configuration. At this moment, we recommend
users who cannot use another IOS to configure their switch to do MAC
Authentication instead (called MAC Authentication Bypass or MAB in Cisco's
terms) or get in touch with us so we can investigate further.

=head2 Problematic firmwares

12.2(50)SE, 12.2(55)SE were reported as malfunctioning for Port-Security operation.
Avoid these IOS.

12.2(44)SE6 is not sending security violation traps in a specific situation:
if a given MAC is authorized on a port/VLAN, no trap is sent if the device changes port
if the target port has the same VLAN as where the MAC was first authorized.
Without a security violation trap PacketFence can't authorize the port leaving the MAC unauthorized.
Avoid this IOS.

=head2 Delays sending security violation traps

Several IOS are affected by a bug that causes the security violation traps to take a long time before being sent.

In our testing, only the first traps were slow to come, the following were fast enough for a proper operation.
So although in testing they can feel like they are broken, once installed and active in the field these IOS are Ok.
Get in touch with us if you can reproduce a problematic behavior reliably and we will revisit our suggestion.

Known affected IOS: 12.2(44)SE2, 12.2(44)SE6, 12.2(52)SE, 12.2(53)SE1, 12.2(55)SE3

Known fixed IOS: 12.2(58)SE1

=head2 Port-Security with Voice over IP (VoIP)

=head2 Security table corruption issues with firmwares 12.2(46)SE or greater and PacketFence before 2.2.1

Several firmware releases have an SNMP security table corruption bug that happens only when VoIP devices are involved.

Although a Cisco problem we developed a workaround in PacketFence 2.2.1 that requires switch configuration changes.
Read the UPGRADE guide under 'Upgrading to a version prior to 2.2.1' for more information.

Firmware versions 12.2(44)SE6 or below should not upgrade their configuration.

Affected firmwares includes at least 12.2(46)SE, 12.2(52)SE, 12.2(53)SE1, 12.2(55)SE1, 12.2(55)SE3 and 12.2(58)SE1.

=head2 12.2(25r) disappearing config

For some reason when securing a MAC address the switch loses an important portion of its config.
This is a Cisco bug, nothing much we can do. Don't use this IOS for VoIP.
See issue #1020 for details.

=head2 SNMPv3

12.2(52) doesn't work in SNMPv3

=head1 CONFIGURATION AND ENVIRONMENT

F<conf/switches.conf>

=head1 SNMP

This switch can parse SNMP traps and change a VLAN on a switch port using SNMP.

=cut

use strict;
use warnings;
use pf::log;
use Net::SNMP;
use Try::Tiny;

use base ('pf::Switch::Cisco::Cisco_IOS_15_0');
use pf::constants;
use pf::config qw(
    $WIRED_802_1X
    $WIRED_MAC_AUTH
    $WEBAUTH_WIRED
    %ConfigRoles
);
use pf::Switch::constants;
use pf::util;
use pf::util::radius qw(perform_coa);
use pf::web::util;
use pf::radius::constants;
use pf::locationlog qw(locationlog_get_session);

sub description { 'Cisco IOS v15.5' }

# CAPABILITIES
# access technology supported
# VoIP technology supported
# override Cisco_IOS_12_x's FALSE
use pf::SwitchSupports qw(
    WiredMacAuth
    WiredDot1x
    RadiusVoip
    RadiusDynamicVlanAssignment
    AccessListBasedEnforcement
    DownloadableListBasedEnforcement
    RoleBasedEnforcement
    ExternalPortal
);

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    $args->{'unfiltered'} = $TRUE;
    $args->{'compute_acl'} = $FALSE;
    $self->compute_action(\$args);
    my @super_reply = @{$self->SUPER::returnRadiusAccessAccept($args)};
    my $status = shift @super_reply;
    my %radius_reply = @super_reply;
    my $radius_reply_ref = \%radius_reply;
    return [$status, %$radius_reply_ref] if($status == $RADIUS::RLM_MODULE_USERLOCK);
    my @av_pairs = defined($radius_reply_ref->{'Cisco-AVPair'}) ? @{$radius_reply_ref->{'Cisco-AVPair'}} : ();

    if ( isenabled($self->{_AccessListMap}) && $self->supportsAccessListBasedEnforcement ){
        if( defined($args->{'user_role'}) && $args->{'user_role'} ne "" && defined(my $access_list = $self->getAccessListByName($args->{'user_role'}, $args->{mac})) && !($self->usePushACLs && exists $ConfigRoles{$args->{'user_role'}} )){
            if ($access_list) {
                if ($self->useDownloadableACLs) {
                    my $mac = lc($args->{'mac'});
                    $mac =~ s/://g;
                    my @acl = split("\n", $access_list);
                    $args->{'acl'} = \@acl;
                    $args->{'acl_num'} = '101';
                    push(@av_pairs, "subscriber:service-name=".$args->{'user_role'}."-".$self->setRadiusSession($args));
                } else {
                    my $acl_num = 101;
                    while($access_list =~ /([^\n]+)\n?/g){
                       my $acl = $1;
                       if ($acl !~ /^((in|out)\|)?(permit|deny)/i) {
                            next;
                        }
                        my ($test, $formated_acl) = $self->returnAccessListAttribute($acl_num,$acl);
                        if ($test) {
                            push(@av_pairs, $formated_acl);
                        } else {
                            next;
                        }
                        $acl_num ++;
                        $logger->info("(".$self->{'_id'}.") Adding access list : $formated_acl to the RADIUS reply");
                    }
                    $logger->info("(".$self->{'_id'}.") Added access lists to the RADIUS reply.");
                }
            } else {
                $logger->info("(".$self->{'_id'}.") No access lists defined for this role ". ( defined($args->{'user_role'}) ? $args->{'user_role'} : 'registration' ));
            }
        }
    }

    $radius_reply_ref->{'Cisco-AVPair'} = \@av_pairs;

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

=head2

Return Radius reply in the access-challenge

=cut

sub returnRadiusAdvanced {
    my ($self, $args, $options) = @_;
    my $logger = $self->logger;
    my $status = $RADIUS::RLM_MODULE_OK;
    my ($role, $session_id) = split('-', $args->{'user_name'});
    my $radius_reply_ref = ();
    my @av_pairs;
    $radius_reply_ref->{'control:Proxy-To-Realm'} = 'LOCAL';
    if ($args->{'connection'}->isServiceTemplate) {
        push(@av_pairs, "ACS:CiscoSecure-Defined-ACL=".$args->{'user_name'});
    } elsif ($args->{'connection'}->isACLDownload) {
        my $cache = $self->radius_cache_distributed;
        my $session = $cache->get($session_id);
        $session->{'id_session'} = $session_id;
        # Need to send back a challenge since there is still acl to download
        if (exists $args->{'scope'} && $args->{'scope'} eq 'packetfence.authorize' && scalar @{$session->{'acl'}} > 1 ) {
            $status = $RADIUS::RLM_MODULE_HANDLED;
            $radius_reply_ref->{'control:Response-Packet-Type'} = 11;
            $radius_reply_ref->{'state'} = $session_id;
            for ( my $loops = 0; $loops < $self->ACLsLimit; $loops++ ) {
                last if (scalar @{$session->{'acl'}} == 1);
                my $acl = shift @{$session->{'acl'}};
                if ($acl !~ /^((in|out)\|)?(permit|deny)/i) {
                    next;
                }
                my ($test, $formated_acl) = $self->returnAccessListAttribute($session->{'acl_num'},$acl);
                if ($test) {
                    push(@av_pairs, $formated_acl);
                } else {
                    next;
                }
                $session->{'acl_num'} ++;
                $logger->info("(".$self->{'_id'}.") Adding access list : $formated_acl to the RADIUS reply");
                $radius_reply_ref->{'Cisco-AVPair'} = \@av_pairs;
            }
            $logger->info("(".$self->{'_id'}.") Added access lists to the RADIUS reply.");
            $self->setRadiusSession($session);
            return [$status, %$radius_reply_ref];
        }
        if (scalar @{$session->{'acl'}} == 1) {
            my $acl = shift @{$session->{'acl'}};
            if ($acl =~ /^((in|out)\|)?(permit|deny)/i) {
                my ($test, $formated_acl) = $self->returnAccessListAttribute($session->{'acl_num'},$acl);
                if ($test) {
                    push(@av_pairs, $formated_acl);
                    $logger->info("(".$self->{'_id'}.") Adding access list : $formated_acl to the RADIUS reply");
                    $logger->info("(".$self->{'_id'}.") Added access lists to the RADIUS reply.");
                    $self->setRadiusSession($session);
                } else {
                    $logger->info("(".$self->{'_id'}.") No more access lists defined for this role ". ( defined($args->{'user_role'}) ? $args->{'user_role'} : 'registration' ));
                }
            } else {
                $logger->info("(".$self->{'_id'}.") No more access lists defined for this role ". ( defined($args->{'user_role'}) ? $args->{'user_role'} : 'registration' ));
            }
        } elsif (scalar @{$session->{'acl'}} == 0) {
            $logger->info("(".$self->{'_id'}.") No more access lists defined for this role ". ( defined($args->{'user_role'}) ? $args->{'user_role'} : 'registration' ));
        } else {
            $logger->info("(".$self->{'_id'}.") No access lists defined for this role ". ( defined($args->{'user_role'}) ? $args->{'user_role'} : 'registration' ));
        }
    }
    $radius_reply_ref->{'Cisco-AVPair'} = \@av_pairs;
    return [$status, %$radius_reply_ref];
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
