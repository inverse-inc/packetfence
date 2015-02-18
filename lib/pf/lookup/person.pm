package pf::lookup::person;

=head1 NAME

pf::lookup::person - lookup person information

=head1 SYNOPSYS

The lookup_person function is called via 
"pfcmd lookup person E<lt>pidE<gt>"
through the administrative GUI,
or as the content of a violation action

Define this function to return whatever data you'd like.

=cut

use strict;
use warnings;
use Net::LDAP;

use pf::person;

sub lookup_person {
    my ($pid,$source_id) = @_;
    my $logger = Log::Log4perl::get_logger('pf::lookup::person');
    my $source = pf::authentication::getAuthenticationSource($source_id);
    if (!$source) {
       $logger->info("Unable to locate the source $source_id");
       return "Unable to locate the source $source_id!\n";
    } 
    
    unless (person_exist($pid)) {
        return "Person $pid is not a registered user!\n";
    }
    my $result = $source->search_attributes($pid);
    if (!$result) {
       $logger->info("Unable to locate PID in LDAP '$pid'");
       return "Unable to locate PID in LDAP '$pid'!\n";
    } 
    # prepare to modify person's entry based on info found
    my %person;
    $person{'firstname'} = $result->get_value("givenName") if (defined($result->get_value("givenName")));
    $person{'lastname'} = $result->get_value("sn") if (defined($result->get_value("sn")));
    $person{'address'} = $result->get_value("physicalDeliveryOfficeName") if (defined($result->get_value("physicalDeliveryOfficeName")));
    $person{'telephone'} = $result->get_value("telephoneNumber") if (defined($result->get_value("telephoneNumber")));
    $person{'email'} = $result->get_value("mail") if (defined($result->get_value("mail")));
    $person{'work_phone'} = $result->get_value("homePhone") if (defined($result->get_value("homePhone")));
    $person{'cell_phone'} = $result->get_value("mobile") if (defined($result->get_value("mobile")));
    $person{'company'} = $result->get_value("company") if (defined($result->get_value("company")));
    $person{'title'} = $result->get_value("title") if (defined($result->get_value("title")));
    
    person_modify($pid, %person) if (%person);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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
