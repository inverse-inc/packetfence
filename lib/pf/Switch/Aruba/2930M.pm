package pf::Switch::Aruba::2930M;

=head1 NAME

pf::Switch::Aruba::2930M - Object oriented module to access Aruba 2930M switches.

=head1 SYNOPSIS

The pf::Switch::Aruba::2930M module implements an object oriented
interface to access Aruba 2930M switches using the ArubaOS-Switch 
operating system version 16.x and up to configure dynamic ACL.

=head1 BUGS AND LIMITATIONS

VoIP not tested using MAC Authentication/802.1X

=cut

use strict;
use warnings;
use base ('pf::Switch::HP::Procurve_2920');
use pf::constants;
use pf::util;
use pf::radius::constants;
sub description {'Aruba 2930M Series'}

sub supportsAccessListBasedEnforcement { return $TRUE }

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
