package pf::Switch::Dell::N1500_6_8;


=head1 NAME

pf::Switch::Dell::N1500_6_8

=head1 SYNOPSIS

pf::Switch::Dell::N1500_6_8 module manages access to Dell N1500 Series FW version 6.8
Tested on Firmware >= 6.8.0

=head1 STATUS



=cut

use strict;
use warnings;
use pf::log;

use base ('pf::Switch::Dell::N1500');
use pf::constants;
use pf::util;
use Cisco::AccessList::Parser;

sub description { 'N1500 Series FW 6.8' }

# CAPABILITIES
# inherited from N1500

=head2 returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.

Overrides the default implementation to add the dynamic acls

=cut

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
        if( defined($args->{'user_role'}) && $args->{'user_role'} ne "" && defined(my $access_list = $self->getAccessListByName($args->{'user_role'}, $args->{mac}))){
            if ($access_list) {
                my $mac = $args->{'mac'};
                $mac =~ s/://g;
                $access_list = $self->acl_chewer($access_list);
                my @acl = split("\n", $access_list);
                $args->{'acl'} = \@acl;
                $args->{'acl_num'} = '101';
                push(@av_pairs, "ACS:CiscoSecure-Defined-ACL=#ACSACL#$mac-".$self->setRadiusSession($args));
            } else {
                $logger->info("(".$self->{'_id'}.") No access lists defined for this role ".$args->{'user_role'});
            }
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
    $radius_reply_ref->{'control:Proxy-To-Realm'} = 'LOCAL';
    if ($args->{'connection'}->isACLDownload) {
        my $cache = $self->radius_cache_distributed;
        my $session = $cache->get($session_id);
        $session->{'id_session'} = $session_id;
        # Need to send back a challenge since there is still acl to download
        if (exists $args->{'scope'} && $args->{'scope'} eq 'packetfence.authorize' && scalar @{$session->{'acl'}} > 1 ) {
            $status = $RADIUS::RLM_MODULE_HANDLED;
            $radius_reply_ref->{'control:Response-Packet-Type'} = 11;
            $radius_reply_ref->{'state'} = $session_id;
            my @a = (1..64);
            for my $i (@a){
                last if (scalar @{$session->{'acl'}} == 1);
                my $acl = shift @{$session->{'acl'}};
                push(@av_pairs, $self->returnAccessListAttribute($session->{'acl_num'})."=".$acl);
                $session->{'acl_num'} ++;
                $logger->info("(".$self->{'_id'}.") Adding access list : $acl to the RADIUS reply");
                $radius_reply_ref->{'Cisco-AVPair'} = \@av_pairs;
            }
            $logger->info("(".$self->{'_id'}.") Added access lists to the RADIUS reply.");
            $self->setRadiusSession($session);
            push(@av_pairs, "ACS:CiscoSecure-Defined-ACL=$mac-".$session_id);
            return [$status, %$radius_reply_ref];
        }
        if (scalar @{$session->{'acl'}} == 1) {
            my $acl = shift @{$session->{'acl'}};
            push(@av_pairs, $self->returnAccessListAttribute($session->{'acl_num'})."=".$acl);
            $logger->info("(".$self->{'_id'}.") Adding access list : $acl to the RADIUS reply");
            $logger->info("(".$self->{'_id'}.") Added access lists to the RADIUS reply.");
            $self->setRadiusSession($session);
            push(@av_pairs, "ACS:CiscoSecure-Defined-ACL=$mac-".$session_id);
	} elsif (scalar @{$session->{'acl'}} == 1) {
            $logger->info("(".$self->{'_id'}.") No more access lists defined for this role ".$args->{'user_role'});
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
    @require = qw(NAS-Port-Type);
    @found = grep {exists $radius_request->{$_}} @require;
    if ($foundvsa) {
        $connection->isACLDownload($TRUE);
        $connection->isVPN($FALSE);
        $connection->isCLI($FALSE);
    } elsif (@require != @found) {
        $connection->isVPN($FALSE);
        $connection->isCLI($TRUE);
        $connection->isMacAuth($FALSE);
        $connection->transport("Virtual");
    }
}

sub acl_chewer {
    my ($self, $acl) = @_;

    my $acls = "ip access-list extended packetfence\n";
    $acls .= $acl;
    my $p = Cisco::AccessList::Parser->new();
    my ($acl_ref, $objgrp_ref) = $p->parse( 'input' => $acls );

    my $acl_chewed;
    foreach my $acl (@{$acl_ref->{'packetfence'}->{'entries'}}) {
        $acl->{'protocol'} =~ s/\(\)//;
        $acl_chewed .= $acl->{'action'}." ".$acl->{'protocol'}." any host ".$acl->{'destination'}->{'ipv4_addr'}."\n";
    }
    return $acl_chewed;
}


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
