#!/usr/bin/perl

=head1 NAME

to-8.0-authentication-conf.pl

=cut

=head1 DESCRIPTION

Since the stripping of the username is now based on the realm, this walks the user through migrating the settings based on the current strip setting of the authentication sources associated to each realm 

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use pf::IniFiles;
use pf::file_paths qw($authentication_config_file $realm_config_file);
use pf::authentication;
use pf::util;
use pf::constants::realm;

exit 0 unless -e $realm_config_file;
exit 0 unless -e $authentication_config_file;

my $inirealm =
  pf::IniFiles->new( -file => $realm_config_file, -allowempty => 1 );

my $iniauth =
  pf::IniFiles->new( -file => $authentication_config_file, -allowempty => 1 );

my %all_realms = map { $_ => 1 } $inirealm->Sections();
my %stripped_realms;
my %non_stripped_realms;

my %realms_strip_context;

for my $authsection ( $iniauth->Sections() ) {
    next if $authsection =~ / /;

    my $stripped_exists = $iniauth->exists($authsection, 'stripped_user_name');

    next unless($stripped_exists);

    my $stripped = isenabled($iniauth->val($authsection, 'stripped_user_name'));
    my $realms_csv = $iniauth->val($authsection, 'realms');
    my $realms = $realms_csv ? [ split(/\ś*,\s*/, $realms_csv) ] : [];
    $realms = [ map{lc($_)} @$realms ];

    print "Found " . (@$realms > 0 ? join(',', @$realms) : "no") . " realms in source $authsection which has ".($stripped ? "stripped username enabled" : "stripped username disabled") . "\n";

    for my $realm (@$realms) {
        if($stripped) {
            $stripped_realms{$realm} = 1;
        }
        else {
            $non_stripped_realms{$realm} = 1;
        }
    }
}

print "==================================================\n";
print "Found the following stripped realms: ".join(",", keys(%stripped_realms)) . "\n";
print "Found the following non-stripped realms: ".join(",", keys(%non_stripped_realms)) . "\n";
print "==================================================\n";

print "You will now have to decide whether the realms will be stripped from the usernames in 3 contexts\n";
print " - admin is when the username is used to login on the web-based administration interface \n";
print " - portal is when the username is used to login on the captive portal \n";
print " - radius is when the username is used in the authorization phase of 802.1x (excludes FreeRADIUS authentication). Also used for authenticating RADIUS requests for CLI access. \n";

for my $realm (keys(%all_realms)) {
    my $realm = lc($realm);

    next if($realm eq "null");
    next if($realm eq "local");

    print "==================================================\n";

    if($realm eq "default") {
        print "Now, you are adjusting the default realm which captures all the non-configured realms.\nHINT: Usually, you'll want to keep this unstripped on the captive portal since it will strip email addresses when they are being used for login. \n";
    }
    elsif(exists($stripped_realms{$realm}) && exists($non_stripped_realms{$realm})) {
        print "Found realm $realm which is set to be stripped and not stripped in different sources. This usually means the username shouldn't be stripped as it is used as-is in some cases. \n";
    }
    elsif (!exists($stripped_realms{$realm}) && exists($non_stripped_realms{$realm})) {
        print "Found realm $realm which is set to be exclusively non-stripped.\nHINT: This usually means the username shouldn't be stripped as it is used as-is in all cases. \n";
    }
    elsif (exists($stripped_realms{$realm}) && !exists($non_stripped_realms{$realm})) {
        print "Found realm $realm which is set to be exclusively stripped.\nHINT: This usually means the username should be stripped as the sources don't expect it to contain the realm. \n";
    }
    else {
        print "Found realm $realm which isn't set to be stripped nor to be kept as-is (non-stripped).\nHINT: This usually means the username should be stripped but your milleage may vary. \n";
    }

    $realms_strip_context{$realm} = {}; 

    for my $context (@pf::constants::realm::CONTEXTS) {
        print "Should the usernames containing this realm be stripped when they are using in the following context: $context? (y/n) ";
        my $confirm = <STDIN>;
        chomp $confirm;
        
        $realms_strip_context{$realm}{$context} = ($confirm eq "y") ? 1 : 0;

    }
}

print "==================================================\n";
print "Summary of the changes: \n";

while(my ($realm, $realm_contexts) = each %realms_strip_context) {
    my @stripped = map{ ($realm_contexts->{$_}) ? $_ : () } keys(%$realm_contexts);
    my @not_stripped = map{ ($realm_contexts->{$_}) ? () : $_ } keys(%$realm_contexts);

    print "Realm $realm will be stripped in the following contexts: ".( @stripped ? join(",", @stripped) : "none" ).", and not stripped in the following: " . (@not_stripped ? join(",", @not_stripped) : "none") . "\n";
}

print "Commit these changes to the configuration file? (y/n) ";
my $confirm = <STDIN>;
chomp $confirm;

if($confirm ne "y") {
    print "Exiting on user's input \n";
    exit 1;
}

for my $section ( $inirealm->Sections() ) {
    my $realm = lc($section);

    #print "$realm \n";
    
    my $contexts = $realms_strip_context{$realm};

    while(my ($context, $strip_enabled) = each(%$contexts)) {
        my $param_name = $context . "_strip_username";
        my $param_enabled = $strip_enabled ? "enabled" : "disabled";
        #print "$param_name => $param_enabled \n";
        $inirealm->newval($section, $param_name, $param_enabled);
    }
}

for my $section ( $iniauth->Sections() ) {
    $iniauth->delval($section, "stripped_user_name");
}

$inirealm->RewriteConfig();
$iniauth->RewriteConfig();

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
