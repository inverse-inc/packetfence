package pf::UnifiedApi::Controller::Config::ConnectionProfiles;

=head1 NAME

pf::UnifiedApi::Controller::Config::ConnectionProfiles -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::ConnectionProfiles

=cut

use strict;
use warnings;
use Mojo::Base qw(pf::UnifiedApi::Controller::Config);
use pf::ConfigStore::Profile;
use pfappserver::Form::Config::Profile;
use pfappserver::Form::Config::Profile::Default;
use JSON::MaybeXS qw();
use File::Find;
use File::stat;
use File::Spec::Functions qw(catfile splitpath);
use pf::util;
use List::Util qw(any first);
use pf::file_paths qw(
    $captiveportal_profile_templates_path
    $captiveportal_default_profile_templates_path
    $captiveportal_templates_path
);

has 'config_store_class' => 'pf::ConfigStore::Profile';
has 'form_class' => 'pfappserver::Form::Config::Profile';
has 'primary_key' => 'connection_profile_id';

sub form {
    my ($self, $item) = @_;
    if ( ($item->{id} // '') eq 'default') {
        return pfappserver::Form::Config::Profile::Default->new;
    }
    return $self->SUPER::form($item);
}

=head2 files

files

=cut

sub files {
    my ($self) = @_;
    return $self->render(
        json => profileFileListing($self->id)
    );
}

=head2 get_file

get_file

=cut

sub get_file {
    my ($self) = @_;
    my $file = $self->stash->{file_name};
    if ($file =~ /(\/)?\.\.\//) {
       return $self->render_error(412, "invalid characters in file '$file'");
    }

    my $id = $self->id;
    my $path = findPath($id, $file);
    if (!defined $path) {
        return $self->render_error(404, "'$file' not found");
    }

    return $self->reply->file($path);
    return $self->render( json => {file => $file, path => $path});
}

sub findPath {
    my ($profile, $file) = @_;
    return first { -f $_ } map { catfile($_, $file) } pathLookup($profile);
}

=head2 profileFileListing

profileFileListing

=cut

sub profileFileListing {
    my ($id) = @_;
    return mergePaths(pathLookup($id));
}

=head2 pathLookup

parent paths

=cut

sub pathLookup {
    my ($profile) = @_;
    my @dirs = (catfile($captiveportal_profile_templates_path, $profile));
    if ($profile eq 'default') {
        push @dirs, $captiveportal_templates_path;
    } else {
        push @dirs, $captiveportal_default_profile_templates_path, $captiveportal_templates_path;
    }

    return @dirs;
}

=head2 mergePaths

mergePaths

=cut

sub mergePaths {
    my ($templateDir, @parentDirs) = @_;
    my %paths;
    my $root;
    find(
        {
            wanted => sub {
                my $full_path = my $path = $_;
                #Just get the file path minus the parent directory
                $path =~ s/^\Q$File::Find::topdir\E\/?//;
                return if exists $paths{$path};
                my $dir = $File::Find::dir;
                #Just get the directory path minus the parent directory
                $dir =~ s/^\Q$File::Find::topdir\E\/?//;
                my $data;
                if ( -d $full_path ) {
                    if (dir_excluded($path)) {
                       $File::Find::prune = 1;
                       return;
                    }

                    $data = { name => file_name($path), type => 'dir', size => 0, entries => [] };
                }
                else {
                    return if file_excluded($path);
                    $data = makeFileInfo( $path, $full_path, @parentDirs );
                }

                $paths{$path} = $data;
                if ( $path ne '' ) {
                    push @{ $paths{$dir}{entries} }, $data;
                }
            },
            no_chdir => 1
        },
        $templateDir,
        @parentDirs
    );

    $root = $paths{''};;
    sortEntry($root);
    return $root;
}

sub file_name {
    my ($path) = @_;
    my (undef, undef, $file) = splitpath($path);
    return $file;
}

=head2 file_excluded

file_excluded

=cut

sub file_excluded {
    my ($file) = @_;
    return $file !~ /\.(html|mjml)$/ || $file =~ /^\./;
}

sub dir_excluded {
    my ($dir) = @_;
    return $dir =~ /\/node_modules/ || $dir =~ /^\./;
}

sub makeFileInfo {
    my ($short_path, $full_path, @parentPaths) = @_;
    my $stat = stat($full_path);
    return {
        type  => 'file',
        name  => file_name($short_path),
        size  => $stat->size,
        mtime => $stat->mtime,
        not_deletable => notDeletable($short_path, @parentPaths),
    };
}

=head2 notDeletable

notDeletable

=cut

sub notDeletable {
    my ($short_path, @parentPaths) = @_;
    return ( any { -f catfile($_, $short_path) } @parentPaths ) ? json_false() : json_true();
}

=head2 sortEntry

Sorts the dir entries by name

=cut

sub sortEntry {
    my ($root) = @_;
    if ($root->{type} eq 'dir' && exists $root->{entries}) {
        my $entries = $root->{entries};
        foreach my $entry (@$entries) {
            if ($entry->{type} eq 'dir') {
                sortEntry($entry);
            }
        }

        @$entries = sort { $a->{type} eq $b->{type} ? $a->{name} cmp $b->{name} : $a->{type} cmp $b->{type} } @$entries;
    }
}

sub json_true {
    return do { bless \(my $a = 1), "JSON::PP::Boolean" };
}

sub json_false {
    return do { bless \(my $a = 0), "JSON::PP::Boolean" };
}

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

1;
