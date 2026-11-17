#!/usr/bin/perl

=head1 NAME

addons/upgrade/to-16.0-http-source-defaults.pl

=cut

=head1 DESCRIPTION

Write the values of the existing HTTP sources of authentication.conf that the
new parameters don't have yet:

=over

=item verify_tls=disabled: the sources created before the option existed did
not verify TLS, while the new sources verify it by default.

=item content_type=application/x-www-form-urlencoded: the only format the
existing sources sent.

=back

It runs before add-default-params-to-auth.pl, which would write the defaults
of the new sources in them.

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use pf::file_paths qw($authentication_config_file);
use pf::util;

main() if not caller();

sub main {
    unless (-e $authentication_config_file) {
        print "$authentication_config_file does not exist\n";
        exit 0;
    }

    run_as_pf();

    my $ini = pf::IniFiles->new(-file => $authentication_config_file, -allowempty => 1);
    if (add_http_source_defaults($ini)) {
        $ini->RewriteConfig();
    }
}

=head2 add_http_source_defaults

Writes the values of %HTTP_SOURCE_DEFAULTS missing from the HTTP sources.
Returns the number of values written.

=cut

our %HTTP_SOURCE_DEFAULTS = (
    verify_tls   => 'disabled',
    content_type => 'application/x-www-form-urlencoded',
);

sub add_http_source_defaults {
    my ($ini) = @_;
    my $updated = 0;
    for my $section ($ini->Sections()) {
        next if $section =~ / /;
        next if ($ini->val($section, 'type') // '') ne 'HTTP';
        for my $name (sort keys %HTTP_SOURCE_DEFAULTS) {
            next if $ini->exists($section, $name);
            my $value = $HTTP_SOURCE_DEFAULTS{$name};
            $ini->newval($section, $name, $value);
            print "Set $name to '$value' in the HTTP source $section\n";
            $updated++;
        }
    }
    if ($updated) {
        print "Enable verify_tls in the HTTP sources whose API certificate is trusted\n";
    }
    return $updated;
}

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
