package pf::util::template_switch;

=head1 NAME

pf::util::template_switch -

=head1 DESCRIPTION

pf::util::template_switch

=cut

use strict;
use warnings;
use File::Find ();
use Module::Loaded qw(mark_as_loaded is_loaded);
use pf::config::template_switch qw(%TemplateSwitches);

sub getDefFiles {
    my ($def_dir) = @_;
    my @files;
    File::Find::find(
        {
            wanted => sub {
                my ( $dev, $ino, $mode, $nlink, $uid, $gid );
                ( ( $dev, $ino, $mode, $nlink, $uid, $gid ) = lstat($_) ) &&
                  -f _ &&
                  /^.*\.def\z/s &&
                  push @files, $File::Find::name;
              }
        },
        $def_dir
    );

    return @files;
}

sub fileNameToModuleName {
    my ($base_dir, $file) = @_;
    my $name = $file;
    $name =~ s/\Q$base_dir\E\///;
    $name =~ s/\//::/g;
    $name =~ s/\.def$//;
    return $name;
}

sub createFakeTemplateModule {
    my ($class) = @_;
    if (is_loaded($class)) {
        return;
    }

    my $type = $class;
    $type =~ s/^pf::Switch:://;
    require pf::Switch::Template;
    no strict "refs";
    my $ref = \*{$class};
    *{"${class}::ISA"} = ["pf::Switch::Template"];
    *{"${class}::_template"} = sub {
        return exists $TemplateSwitches{$type} ? $TemplateSwitches{$type} : undef;
    };
    mark_as_loaded($class);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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
