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
    
    my $result = $source->search_attribute($pid,$source_id);
    my $return = "";

    if (person_exist($pid)) {

        if (!$source) {
            $logger->info("pfcmd: pidinfo: unable to locate PID '$pid'");
            $return = "Unable to locate PID '$pid'!\n";
        } 
        else {
            
            # Get informations from the function search_attribute() based on the pid
            my $firstname = $result->get_value("givenName");
            my $lastname = $result->get_value("sn");
            my $address = $result->get_value("physicalDeliveryOfficeName");
            my $phone = $result->get_value("telephoneNumber");
            my $email = $result->get_value("mail");
            my $mobile = $result->get_value("mobile");
            my $homephone = $result->get_value("homePhone");
            my $company = $result->get_value("company");
            my $title = $result->get_value("title");

            # Display all retrieved informations in the packetfence.log
            $return .= "The following info was fetched from AD\n";
            $return .= "Id : $pid\n";
            $return .= "First name : $firstname\n" if (defined($firstname));
            $return .= "Last name : $lastname\n" if (defined($lastname));
            $return .= "Address : $address\n" if (defined($address));
            $return .= "Work phone : $phone\n" if (defined($phone));
            $return .= "Email : $email\n" if (defined($email));
            $return .= "Work phone : $homephone\n" if (defined($homephone));
            $return .= "Cell phone : $mobile\n" if (defined($mobile));
            $return .= "Company : $company\n" if (defined($company));
            $return .= "Title : $title\n" if (defined($title));

            $logger->info($return);

            # prepare to modify person's entry based on info found
            my %person;
            $person{'firstname'} = $firstname if (defined($firstname));
            $person{'lastname'} = $lastname if (defined($lastname));
            $person{'address'} = $address if (defined($address));
            $person{'telephone'} = $phone if (defined($phone));
            $person{'email'} = $email if (defined($email));
            $person{'work_phone'} = $homephone if (defined($homephone));
            $person{'cell_phone'} = $mobile if (defined($mobile));
            $person{'company'} = $company if (defined($company));
            $person{'title'} = $title if (defined($title));
            
            person_modify($pid, %person) if (%person);
        }
    }
    else {
        $return = "Person $pid is not a registered user!\n";
    }
    return $return;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
