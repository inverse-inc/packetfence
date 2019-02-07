package pf::Switch::Aruba::5400;

=head1 NAME

pf::Switch::Aruba::5400

=head1 SYNOPSIS

Module to manage rebanded Aruba HP 5400 switches

=head1 STATUS

=over

=item Supports

=over

=item MAC-Authentication

=item 802.1X

=item Radius downloadable ACL support

=item Voice over IP

=item Radius CLI Login

=back

=back

Has been reported to work on Aruba 5400 (HPE Procurve 5400)

=cut

use strict;
use warnings;
use Net::SNMP;

use base ('pf::Switch::HP::Procurve_2500');

use pf::constants;
use pf::config qw(
    $MAC
    $PORT
);
use pf::Switch::constants;
use pf::util;

sub description { 'Aruba 5400 Switch' }

# CAPABILITIES
# access technology supported
sub supportsWiredMacAuth { return $TRUE; }
sub supportsWiredDot1x { return $TRUE; }
# VoIP technology supported
sub supportsRadiusVoip { return $TRUE; }
# inline capabilities
sub inlineCapabilities { return ($MAC,$PORT); }

#Insert your voice vlan name, not the ID.
our $VOICEVLANAME = "voip";

# Downloadable ACLs
sub supportsAccessListBasedEnforcement { return $TRUE }

=over

Return radius attributes to allow write access

=cut

sub returnAuthorizeWrite {
   my ($self, $args) = @_;
   my $logger = $self->logger;
   my $radius_reply_ref = {};
   my $status;
   $radius_reply_ref->{'Service-Type'} = 'Administrative-User';
   $radius_reply_ref->{'Reply-Message'} = "Switch enable access granted by PacketFence";
   $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with write access");
   my $filter = pf::access_filter::radius->new;
   my $rule = $filter->test('returnAuthorizeWrite', $args);
   ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
   return [$status, %$radius_reply_ref];
}

=item returnAuthorizeRead

Return radius attributes to allow read access

=cut

sub returnAuthorizeRead {
   my ($self, $args) = @_;
   my $logger = $self->logger;
   my $radius_reply_ref = {};
   my $status;
   $radius_reply_ref->{'Service-Type'} = 'NAS-Prompt-User';
   $radius_reply_ref->{'Reply-Message'} = "Switch read access granted by PacketFence";
   $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with read access");
   my $filter = pf::access_filter::radius->new;
   my $rule = $filter->test('returnAuthorizeRead', $args);
   ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
   return [$status, %$radius_reply_ref];
}

=head2 returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Overrides the default implementation to add the dynamic acls

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;
    $args->{'unfiltered'} = $TRUE;
    my @super_reply = @{$self->SUPER::returnRadiusAccessAccept($args)};
    my $status = shift @super_reply;
    my %radius_reply = @super_reply;
    my $radius_reply_ref = \%radius_reply;
    return [$status, %$radius_reply_ref] if($status == $RADIUS::RLM_MODULE_USERLOCK);
    my @acls = defined($radius_reply_ref->{'NAS-Filter-Rule'}) ? @{$radius_reply_ref->{'NAS-Filter-Rule'}} : ();

    if ( isenabled($self->{_AccessListMap}) && $self->supportsAccessListBasedEnforcement ){
        if( defined($args->{'user_role'}) && $args->{'user_role'} ne "" && defined($self->getAccessListByName($args->{'user_role'}))){
            my $access_list = $self->getAccessListByName($args->{'user_role'});
            if ($access_list) {
                while($access_list =~ /([^\n]+)\n?/g){
                    push(@acls, $1);
                    $logger->info("(".$self->{'_id'}.") Adding access list : $1 to the RADIUS reply");
                }
                $logger->info("(".$self->{'_id'}.") Added access lists to the RADIUS reply.");
            } else {
                $logger->info("(".$self->{'_id'}.") No access lists defined for this role ".$args->{'user_role'});
            }
        }
    }

    $radius_reply_ref->{'NAS-Filter-Rule'} = \@acls;

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}
=over

=item getVoipVSA

Get Voice over IP RADIUS Vendor Specific Attribute (VSA).

TODO: Use Egress-VLANID instead. See: http://wiki.freeradius.org/HP#RFC+4675+%28multiple+tagged%2Funtagged+VLAN%29+Assignment

=cut

sub getVoipVsa {
    my ($self) = @_;
    my $logger = $self->logger;

    return ('Egress-VLAN-Name' => "1".$VOICEVLANAME);
}

=item isVoIPEnabled

Is VoIP enabled for this device

=cut

sub isVoIPEnabled {
    my ($self) = @_;
    return ( $self->{_VoIPEnabled} == 1 );
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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
