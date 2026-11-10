#!/usr/bin/perl

=head1 NAME

add-default-params-to-auth

=cut

=head1 DESCRIPTION

Add default required fields for SQL Twilio and SMS sources

=cut

use strict;
use warnings;
use lib qw(/usr/local/pf/lib /usr/local/pf/lib_perl/lib/perl5);
use pf::IniFiles;
use Module::Load;
use pf::util;
use pf::file_paths qw($authentication_config_file);
use Getopt::Long;
use Module::Pluggable
  'search_path' => [qw(pf::Authentication::Source)],
  'sub_name'    => 'sources',
  'require'     => 1,
  'inner'       => 0,
  ;

sources();

our %attributes_to_skip = (
    (
        map { $_ => 1 } (pf::Authentication::Source->meta->get_attribute_list(), "_ldap_attributes")
    )
);

delete @attributes_to_skip{qw(dynamic_routing_module)};

main() if not caller();

sub main {
    my $dry_run = 0;

    GetOptions("dry-run|n" => \$dry_run);

    unless (-e $authentication_config_file) {
        print "$authentication_config_file does not exists\n";
        exit 0;
    }

    run_as_pf();

    my $ini = pf::IniFiles->new(
        -file => $authentication_config_file,
        -allowempty => 1,
    );

    add_default_params($ini, $dry_run);

    if (!$dry_run) {
        $ini->RewriteConfig();
    }
}

=head2 add_default_params

Writes the default of each attribute missing from the sources of an
authentication.conf. A source class can give, with legacy_defaults, the value
of an attribute for the existing sources when it differs from the default of
the new sources.

=cut

sub add_default_params {
    my ($ini, $dry_run) = @_;
    for my $section ($ini->Sections()) {
        next if $section =~ / / || !$ini->exists( $section, 'type' );
        my $type = $ini->val($section, 'type');
        my $class = "pf::Authentication::Source::${type}Source";
        load $class;
        if ($dry_run) {
            print "Will update $section ($type)\n";
        } else {
            print "Updating $section ($type)\n";
        }
        my $legacy_defaults = $class->can('legacy_defaults') ? $class->legacy_defaults : {};
        my $meta = $class->meta;
        for my $attr ($meta->get_all_attributes()) {
            my $name = $attr->name;
            my $value = exists $legacy_defaults->{$name} ? $legacy_defaults->{$name}
                      : $attr->is_default_a_coderef ? $attr->default->() : $attr->default;
            next unless defined $value;
            next if exists $attributes_to_skip{$name} || $ini->exists($section, $name);
            if ($dry_run) {
                print " Will set $name to '$value'\n";
            } else {
                print " Setting $name to '$value'\n";
                $ini->newval($section, $name, $value);
            }
        }

        print "\n";
    }
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
