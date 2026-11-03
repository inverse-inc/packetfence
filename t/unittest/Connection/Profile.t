#!/usr/bin/perl

=head1 NAME

Profile

=head1 DESCRIPTION

unit test for pf::Connection::Profile

=cut

use strict;
use warnings;

BEGIN {
    #include test libs
    use lib qw(/usr/local/pf/t);
    #Module for overriding configuration paths
    use setup_test_config;
}

use Test::More tests => 6;

#This test will running last
use Test::NoWarnings;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use pf::Connection::Profile;

my $profile_dir = tempdir(CLEANUP => 1);
my $default_dir = tempdir(CLEANUP => 1);

sub touch {
    my ($dir, $file) = @_;
    make_path("$dir/security_events");
    open(my $fh, '>', "$dir/$file") or die "Cannot create $dir/$file: $!";
    close($fh);
}

# The default templates have a translation of generic.html
touch($default_dir, "security_events/generic.html");
touch($default_dir, "security_events/generic.fr.html");
touch($default_dir, "security_events/other.html");

my $profile = pf::Connection::Profile->new({ template_paths => [$profile_dir, $default_dir] });

is(
    $profile->findSecurityEventTemplate("generic", ["fr", "en_US"]),
    "security_events/generic.fr.html",
    "The translation of the default templates is used when the profile doesn't customize the template",
);

is(
    $profile->findSecurityEventTemplate("generic", ["en_US"]),
    "security_events/generic.html",
    "The default template is used when there is no translation for the language",
);

# The profile customizes generic.html only
touch($profile_dir, "security_events/generic.html");

is(
    $profile->findSecurityEventTemplate("generic", ["fr", "en_US"]),
    "security_events/generic.html",
    "The template customized in the profile is used instead of the translation of the default templates",
);

# The profile also customizes the french translation
touch($profile_dir, "security_events/generic.fr.html");

is(
    $profile->findSecurityEventTemplate("generic", ["fr_FR", "en_US"]),
    "security_events/generic.fr.html",
    "The translation customized in the profile is used for its language",
);

is(
    $profile->findSecurityEventTemplate("other", ["fr", "en_US"]),
    "security_events/other.html",
    "A template not customized in the profile is found in the default templates",
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
