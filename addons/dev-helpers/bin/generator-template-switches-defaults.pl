#!/usr/bin/perl

use strict;
use FindBin qw($Bin);;
use lib "$Bin/../../../lib";
use pf::mini_template;
use pf::config::builder::template_switches;
use pf::util::template_switch;
use Cwd 'abs_path';
use pf::IniFiles;
use pf::file_paths qw($template_switches_default_config_file);

my $def_dir = abs_path( "$Bin/../../../lib/pf/Switch" ) ;
my $conf_dir = abs_path( "$Bin/../../../conf" ) ;

my $default_ini = pf::IniFiles->new();
my $builder = pf::config::builder::template_switches->new;
# Traverse desired filesystems
#File::Find::find({wanted => \&wanted}, $def_dir);
print "Loading files from $def_dir\n";
my @files = pf::util::template_switch::getDefFiles($def_dir);
for my $file (sort @files) {
    print " processing $file \n";
    my $name = pf::util::template_switch::fileNameToModuleName($def_dir, $file);
    my $ini = pf::IniFiles->new( -file => $file, -fallback => $name);
    unless ($ini) {
        print STDERR "Error loading file '$file'\n";
        print STDERR "Please fix error not updating '$template_switches_default_config_file'\n\n";
        exit;
    }
    my ($error, undef) = $builder->build($ini);
    if ($error) {
        $error = $error->[0];
        print STDERR "  Error when building '$file'\n    $error->{message}\n";
        for my $err (@{$error->{errors}}) {
            print STDERR "      Attribute $err->{name}\n";
            my $message = $err->{message};
            $message =~ s/^/       /gm;
            print STDERR $message,"\n";
        }
        print STDERR "Please fix error not updating '$template_switches_default_config_file'\n\n";
        exit ;
    }

    $default_ini->AddSection($name);
    for my $p ($ini->Parameters($name)) {
        $default_ini->newval($name, $p, $ini->val($name, $p));   
    }
}

$default_ini->WriteConfig($template_switches_default_config_file);


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
