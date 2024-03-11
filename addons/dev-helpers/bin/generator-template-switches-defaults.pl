#!/usr/bin/perl

use strict;
use FindBin qw($Bin);
use lib ("$Bin/../../../lib", "$Bin/../../../lib_perl/lib/perl5");
use pf::mini_template;
use pf::config::builder::template_switches;
use pf::util::template_switch;
use Cwd 'abs_path';
use pf::IniFiles;
use pf::file_paths qw($template_switches_default_config_file);

my $def_dir = abs_path( "$Bin/../../../lib/pf/Switch" ) ;
my $conf_dir = abs_path( "$Bin/../../../conf" ) ;

my $default_ini = pf::IniFiles->new( -fallback => '__GENERAL__');
$default_ini->{fallback_used} = 1;
#Adding the comments at the 
$default_ini->AddSection('__GENERAL__');
$default_ini->SetSectionComment(
    '__GENERAL__',
    "Do not edit file.",
    "Changes will be lost on upgrade.",
);
my $builder = pf::config::builder::template_switches->new;
# Traverse desired filesystems
#File::Find::find({wanted => \&wanted}, $def_dir);
print "Loading files from $def_dir\n";
my @files = pf::util::template_switch::getDefFiles($def_dir);
my $SPACES = ' ';
for my $file (sort @files) {
    print " processing $file \n";
    my $name = pf::util::template_switch::fileNameToModuleName($def_dir, $file);
    my $module = $file;
    $module =~ s/\.def$/.pm/;
    if (-e $module) {
        print STDERR "Error: $module exists\n";
        next;
    }

    my $ini = pf::IniFiles->new( -file => $file, -fallback => $name);
    unless ($ini) {
        print STDERR "Error loading file '$file'\n";
        print STDERR "Please fix error not updating '$template_switches_default_config_file'\n\n";
        exit;
    }
    my ($errors, undef) = $builder->build($ini);
    if ($errors && @$errors) {
        print STDERR $SPACES x 2, "Error when building '$file'\n";
        foreach my $error (@$errors) {
            print STDERR $SPACES x 3 ,"$error->{message}\n";
            for my $err (@{$error->{errors}}) {
                print STDERR $SPACES x 4,"Attribute $err->{name}\n";
                my $message = $err->{message};
                my $s4 = $SPACES x 5;
                $message =~ s/^/$s4/egm;
                print STDERR $message,"\n";
            }
        }
        print STDERR "Please fix error not updating '$template_switches_default_config_file'\n\n";
        exit ;
    }

    $default_ini->AddSection($name);
    my @comments = $ini->GetSectionComment($name);
    if (@comments && defined $comments[0]) {
        $default_ini->SetSectionComment($name, @comments);
    }

    for my $p ($ini->Parameters($name)) {
        $default_ini->newval($name, $p, $ini->val($name, $p));   
        my @comments = $ini->GetParameterComment($name, $p);
        if (@comments && defined $comments[0]) {
            $default_ini->SetParameterComment($name, $p, @comments);
        }
    }
}

$default_ini->WriteConfig($template_switches_default_config_file);


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
