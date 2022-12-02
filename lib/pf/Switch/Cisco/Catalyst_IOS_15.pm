package pf::Switch::Cisco::Catalyst_IOS_15;
=head1 NAME

pf::Switch::Cisco::Catalyst_IOS_15

=head1 DESCRIPTION

Object oriented module to access and configure Cisco Catalyst IOS_15 switches

=head1 STATUS

This module is currently only a placeholder, see L<pf::Switch::Cisco::Cisco_IOS_15> for relevant support items.

This module implement support for a different radius logicfor the IOS_15.

=head1 BUGS AND LIMITATIONS

Most of the code is shared with the 2960 make sure to check the BUGS AND
LIMITATIONS section of L<pf::Switch::Cisco::Catalyst_2960>.

=cut

use strict;
use warnings;

use pf::log;
use pf::util;
use pf::constants;

use base ('pf::Switch::Cisco::Catalyst_2960');

sub description { 'Cisco Catalyst IOS 15' }

# CAPABILITIES
# inherited from 2960

=head1 METHODS

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
    my @av_pairs = defined($radius_reply_ref->{'Cisco-AVPair'}) ? @{$radius_reply_ref->{'Cisco-AVPair'}} : ();

    if ( isenabled($self->{_AccessListMap}) && $self->supportsAccessListBasedEnforcement ){
        if( defined($args->{'user_role'}) && $args->{'user_role'} ne "" && defined(my $access_list = $self->getAccessListByName($args->{'user_role'}, $args->{mac}))){
            if ($access_list) {
                my $mac = lc($args->{'mac'});
                $mac =~ s/://g;
                $args->{'acl'} = $access_list;
                push(@av_pairs, "subscriber:service-name=$mac-".$self->setRadiusSession($args));
            } else {
                $logger->info("(".$self->{'_id'}.") No access lists defined for this role ".$args->{'user_role'});
            }
        }
    }

    my $role = $self->getRoleByName($args->{'user_role'});
    if ( isenabled($self->{_UrlMap}) && $self->externalPortalEnforcement ) {
        if( defined($args->{'user_role'}) && $args->{'user_role'} ne "" && defined($self->getUrlByName($args->{'user_role'}))){
            my $mac = $args->{'mac'};
            $args->{'session_id'} = "sid".$self->setRadiusSession($args);
            my $redirect_url = $self->getUrlByName($args->{'user_role'});
            $redirect_url .= '/' unless $redirect_url =~ m(\/$);
            $redirect_url .= $args->{'session_id'};
            #override role if a role in role map is defined
            if (isenabled($self->{_RoleMap}) && $self->supportsRoleBasedEnforcement()) {
                my $role_map = $self->getRoleByName($args->{'user_role'});
                $role = $role_map if (defined($role_map));
                # remove the role if any as we push the redirection ACL along with it's role
                delete $radius_reply_ref->{$self->returnRoleAttribute()};
            }
            $logger->info("Adding web authentication redirection to reply using role: '$role' and URL: '$redirect_url'");
            push @av_pairs, "url-redirect-acl=$role";
            push @av_pairs, "url-redirect=".$redirect_url;

        }
    }


    $radius_reply_ref->{'Cisco-AVPair'} = \@av_pairs;

    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

sub returnRadiusAdvanced {
    my ($self, $args, $options) = @_;
    my $logger = $self->logger;
    my $status = $RADIUS::RLM_MODULE_OK;
    my ($mac, $session_id) = split('-', $args->{'user_name'});
    my $radius_reply_ref = ();
    my @av_pairs;
    if ($args->{'connection'}->isServiceTemplate) {
        push(@av_pairs, "ACS:CiscoSecure-Defined-ACL=".$args->{'user_name'});
    } elsif ($args->{'connection'}->isACLDownload) {
        my $cache = $self->radius_cache_distributed;
        my $session = $cache->get($session_id);
        # This is where the split and the challenge needs to be done
        # radius reply State = xyz
        # Access-Challenge
        if ($session->{'acl'}) {
            my $acl_num = 101;
            while($session->{'acl'} =~ /([^\n]+)\n?/g){
                push(@av_pairs, $self->returnAccessListAttribute($acl_num)."=".$1);
                $acl_num ++;
                $logger->info("(".$self->{'_id'}.") Adding access list : $1 to the RADIUS reply");
            }
            $logger->info("(".$self->{'_id'}.") Added access lists to the RADIUS reply.");
        } else {
            $logger->info("(".$self->{'_id'}.") No access lists defined for this role ".$args->{'user_role'});
        }
    }
    $radius_reply_ref->{'Cisco-AVPair'} = \@av_pairs;
    return [$status, %$radius_reply_ref];
}


=item identifyConnectionType

Determine Connection Type based on radius attributes

=cut


sub identifyConnectionType {
    my ( $self, $connection, $radius_request ) = @_;
    my $logger = $self->logger;

    my @require = qw(Cisco-AVPair);
    my @found = grep {exists $radius_request->{$_}} @require;
    my $foundvsa = 0;
    my @vsa = qw(aaa:service=ip_admission aaa:event=acl-download);
    if (exists $radius_request->{'Cisco-AVPair'}) {
        if (ref($radius_request->{'Cisco-AVPair'}) eq 'ARRAY') {
            foreach my $item (@{$radius_request->{'Cisco-AVPair'}}) {
                foreach my $vsa (@vsa) {
                    if ($vsa eq $item) {
                        $foundvsa ++;
                    }
                }
	    }
        }
    }

    if ( (@require == @found) && $radius_request->{'Cisco-AVPair'} =~ /^(download-request=service-template)$/i ) {
        $connection->isServiceTemplate($TRUE);
        $connection->isCLI($FALSE);
        $connection->isVPN($FALSE);
    } elsif ($foundvsa) {
        $connection->isACLDownload($TRUE);
        $connection->isVPN($FALSE);
        $connection->isCLI($FALSE);
    }
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2022 Inverse inc.

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
