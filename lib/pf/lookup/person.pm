package pf::lookup::person;

=head1 NAME

pf::lookup::person - lookup person information

=head1 SYNOPSYS

The lookup_person function is called via 
"pfcmd lookup person E<lt>pidE<gt>"
through the administrative GUI,
or as the content of a violation action

Define this function to return whatever data you'd like.

=head1 EXAMPLE

  use Net::LDAP;
  use Log::Log4perl;

  sub lookup_person {
      my ($pid) = @_;
      my $logger = Log::Log4perl::get_logger('pf::lookup::person');

      my $ldapserver = $Config{'lookup'}{'ldapserver'};
      my $userdn     = $Config{'lookup'}{'userdn'};
      my $username   = $Config{'lookup'}{'ldapuser'};
      my $password   = $Config{'lookup'}{'ldappass'};

      my $return = "";

      if (person_exist($pid)) {

          my $ldap = Net::LDAP->new($ldapserver, version=>3)
              or die("Unable to contact $ldapserver!\n");

          my $msg = $ldap->bind ( $username, 
                                  password => $password, 
                                  version  => 3);
          my $searchresult = $ldap->search ( 
              base => $userdn, 
              filter => "(cn=$pid)"
          );
          my $entry = $searchresult->entry();

          if (!$entry) {
              $logger->info("pfcmd: pidinfo: unable to locate PID '$pid'");
              $return = "Unable to locate PID '$pid'!\n";
          } 
          else {
              my $name = $entry->get_value("cn");
              my $address = $entry->get_value("postalAddress");
              $address =~ s/\$/\n/g;
              my $phone = $entry->get_value("telephoneNumber");
              my $email = $entry->get_value("mail");

              $return .= "Id : $pid\n";
              $return .= "Name : $name\n" if ($name =~ /\W/);
              $return .= "Address : $address\n" if ($address =~ /\W/);
              $return .= "Phone : $phone\n" if ($phone =~ /\W/);
              $return .= "Email : $email\n" if ($email =~ /\W/);

              # If you want to alter the database, you can call person_modify here
              #if ($name =~ /^(.+), (.+)$/) {
              #     person_modify($pid, (firstname => $2, lastname => $1));
              #}

          }
          $ldap->unbind();
      }
      else {
          $return = "Person $pid is not a registered user!\n";
      }

      return $return;
  }

=cut


use strict;
use warnings;

use pf::person;

sub lookup_person {
    my ($pid) = @_;
    if ( person_exist($pid) ) {
        return ($pid);
    } else {
        return ("Person $pid is not a registered user!\n");
    }
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
