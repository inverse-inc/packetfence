#!/usr/bin/perl

=head1 NAME

to-9.1-security-events-remove-useragent.pl

=cut

=head1 DESCRIPTION

Remove the useragent triggers from the security events

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::IniFiles;
use pf::file_paths qw(
    $security_events_config_file
);
use File::Copy;
use pf::util;
use pfappserver::Form::Field::Trigger;

run_as_pf();

exit 0 unless -e $security_events_config_file;
my $ini = pf::IniFiles->new(-file => $security_events_config_file, -allowempty => 1);

for my $section ($ini->Sections()) {
    if (my $triggers = $ini->val($section, 'trigger')) {
        $triggers = [ split(/\s*,\s*/, $triggers) ];
        my $new_triggers = [];
        foreach my $trigger (@$triggers) {
            my $trigger_hash = pfappserver::Form::Field::Trigger->inflate($trigger);
            delete $trigger_hash->{useragent};
            my $new_trigger = pfappserver::Form::Field::Trigger->deflate($trigger_hash);
            if($new_trigger) {
                push @$new_triggers, $new_trigger 
            }
            else {
                print "Trigger for security event $section is now empty. The security event will never trigger automatically anymore.\n";
            }
        }
        $ini->setval($section, 'trigger', join(',', @$new_triggers));
    }
}

$ini->RewriteConfig();


print "All done\n";

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



