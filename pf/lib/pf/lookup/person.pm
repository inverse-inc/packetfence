#
# Copyright 2005 Dave Laporte <dave@laportestyle.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
# Copyright 2009 Inverse groupe conseil <dgehl@inverse.ca>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

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

  sub lookup_person {
      my ($pid) = @_;

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
use diagnostics;

use pf::person;

sub lookup_person {
    my ($pid) = @_;
    if ( person_exist($pid) ) {
        return ($pid);
    } else {
        return ("Person $pid is not a registered user!\n");
    }
}

1;
