package pf::Switch::Cisco::Cisco_WLC_IOS_XE;

=head1 NAME

pf::Switch::Cisco::Cisco_WLC_IOS_XE - Object oriented module to parse SNMP traps and 
manage Cisco Wireless Controllers Series running on Cisco IOS XE.

=head1 STATUS

This module is currently only a placeholder, see L<pf::Switch::Cisco::Cisco_WLC_AireOS> for relevant support items.

=cut

use strict;
use warnings;

use Net::SNMP;
use pf::Switch::constants;
use pf::constants qw($TRUE $FALSE);
use pf::config qw(
    %ConfigRoles
);
use pf::util;

use base ('pf::Switch::Cisco::Cisco_WLC_AireOS');

sub description { 'Cisco WLC (IOS XE)' }

use pf::SwitchSupports qw(
    AccessListBasedEnforcement
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
