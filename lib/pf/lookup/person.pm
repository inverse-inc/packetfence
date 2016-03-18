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

use pf::log;
use pf::person;
use pf::util;
use pf::authentication;
use pf::pfqueue::producer::redis;

=head2 lookup_person

Lookup informations on a person

=cut

sub lookup_person {
    my ($pid,$source_id) = @_;
    my $logger = get_logger();
    my $source = pf::authentication::getAuthenticationSource($source_id);
    if (!$source) {
       $logger->info("Unable to locate the source $source_id");
       return "Unable to locate the source $source_id!\n";
    }

    unless (person_exist($pid)) {
        return "Person $pid is not a registered user!\n";
    }
    my ($person, $msg) = $source->search_attributes($pid);
    if (!$person) {
       $logger->info("Cannot search attributes for user '$pid'");
       return "Cannot search attributes for user '$pid'!\n";
    }

    $logger->info("Successfully did a person lookup for $pid");

    person_modify($pid, %$person);
}

=head2 async_lookup_person

Lookup a person asynchronously using the queue

=cut

sub async_lookup_person {
    my ($pid, $source_id) = @_;
    my $client = pf::pfqueue::producer::redis->new();
    $client->submit("general", person_lookup => {pid => $pid, source_id => $source_id});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
