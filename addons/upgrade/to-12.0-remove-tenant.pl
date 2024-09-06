#!/usr/bin/perl

=head1 NAME

to-12.0-remove-tenant -

=head1 DESCRIPTION

to-12.0-remove-tenant

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib);
use lib qw(/usr/local/pf/lib_perl/lib/perl5);
use pf::file_paths qw(
    $switches_config_file
    $pfdetect_config_file
    $firewall_sso_config_file
    $network_config_file
    $realm_config_file
);
use pf::IniFiles;

my $tenant_id = 1;

my @files = (
    {
        file => $switches_config_file,
        field => 'TenantId',
    },
    {
        file => $pfdetect_config_file,
        field => 'tenant_id',
    },
    {
        file => $network_config_file,
        field => 'tenant_id',
    },
    {
        file => $firewall_sso_config_file,
        field => 'tenant_id',
    },
);

for my $f (@files) {
    removeField($f->{file}, $f->{field});
}

removeTenantGroup($realm_config_file, $tenant_id);

sub removeField {
    my ($file, $fieldName) = @_;
    my $ini = pf::IniFiles->new(
        -file => $file,
        -allowempty => 1,
    );
    my $i = 0;
    for my $section ($ini->Sections()) {
        next if !$ini->exists($section, $fieldName);
        $ini->delval($section, $fieldName);
        $i |= 1;
    }

    if ($i) {
        print "Updated $file\n";
        $ini->RewriteConfig();
    }
}

sub removeTenantGroup {
    my ($file, $tenant) = @_;
    my $ini = pf::IniFiles->new(
        -file => $file,
        -allowempty => 1,
    );
    my $i = 0;
    for my $group ($ini->Groups()) {
        if ($group ne $tenant) {
            for my $sect ($ini->GroupMembers($group)) {
                $ini->DeleteSection($sect);
            }
            $i |= 1;
            next;
        }

        for my $sect ($ini->GroupMembers($group)) {
            my $new_sect = $sect;
            $new_sect =~ s/^\Q$tenant\E //;
            $ini->RenameSection($sect, $new_sect);
            $i |= 1;
        }

    }
    if ($i) {
        print "Updated $file\n";
        $ini->RewriteConfig();
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

