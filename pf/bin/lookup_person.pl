#
# Copyright 2005 Dave Laporte <dave@laportestyle.org>
# Copyright 2005 Kevin Amorin <kev@amorin.org>
#
# See the enclosed file COPYING for license information (GPL).
# If you did not receive this file, see
# http://www.fsf.org/licensing/licenses/gpl.html.
#

# define this function to return whatever data you'd like
# it's called via "pfcmd lookup person <pid>", through the administrative GUI,
# or as the content of a violation action

# have a look at contrib/lookup/lookup_person.pl.ldap for an LDAP example

sub lookup_person {
  my($pid) = @_;
  if (person_exist($pid)) {
    return($pid);
  } else {
    return("Person $pid is not a registered user!\n");
  }
}

return(true);
