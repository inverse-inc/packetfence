package pf::lookup::person;

=head1 NAME

pf::lookup::person - lookup person information

=head1 SYNOPSYS

The lookup_person function is called via
"pfcmd lookup person E<lt>pidE<gt>"
through the administrative GUI,
or as the content of a security_event action

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
use pf::CHI;

my $CHI_CACHE = pf::CHI->new( namespace => 'person_lookup' );

=head2 lookup_person

Lookup informations on a person

=cut

sub lookup_person {
    my ($pid, $source_id, $context) = @_;
    my $logger = get_logger();
    unless (defined $source_id) {
        $logger->info("undefined source id provided");
        return;
    }
    my $source = pf::authentication::getAuthenticationSource($source_id);
    if (!$source) {
       $logger->info("Unable to locate the source $source_id");
       return;
    }
    
    my $stripped;
    if(defined($context)) {
        ($stripped, undef) = pf::config::util::strip_username_if_needed($pid, $context);
    }
    else {
        $stripped = $pid;
        $logger->warn("No context defined for person lookup, username will not be stripped and left as-is ($pid)");
    }

    unless (person_exist($pid)) {
        $logger->info("Person $pid is not a registered user!");
        return;
    }

    my $cache_key = "$source_id.$pid.$context";
    my $person = $CHI_CACHE->get($cache_key);
    unless($person){
        $person = $source->search_attributes($stripped);
        if (!$person) {
           $logger->debug("Cannot search attributes for user '$stripped'");
           return;
        } else {
            $CHI_CACHE->set($cache_key, $person);
            $logger->info("Successfully did a person lookup for $pid");
            person_modify($pid, %$person);
            return;
        }
    }
    $logger->info("Already did a person lookup for $pid");
    return;
}

=head2 async_lookup_person

Lookup a person asynchronously using the queue

=cut

sub async_lookup_person {
    my ($pid, $source_id, $context) = @_;
    my $client = pf::pfqueue::producer::redis->new();
    $client->submit("general", person_lookup => {pid => $pid, source_id => $source_id, context => $context});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

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
