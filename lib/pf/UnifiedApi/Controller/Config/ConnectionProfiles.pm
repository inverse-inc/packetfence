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
use File::Slurp qw(write_file);
use POSIX qw(:errno_h);
use JSON::MaybeXS qw();
use File::Find;
use File::stat;
use File::Spec::Functions qw(catfile splitpath);
use pf::util;
use List::Util qw(any first none);
use pf::file_paths qw(
    $captiveportal_profile_templates_path
    $captiveportal_default_profile_templates_path
    $captiveportal_templates_path
);

has 'config_store_class' => 'pf::ConfigStore::Profile';
has 'form_class' => 'pfappserver::Form::Config::Profile';
has 'primary_key' => 'connection_profile_id';

my %NUMERICAL_SORTS = (
    mtime => undef,
    size => undef,
);

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
    my $file_listing_info = $self->file_listing_info();
    my $cmps = make_compare_functions($file_listing_info->{sort});
    return $self->render(
        json => profileFileListing($self->id, $cmps)
    );
}

=head2 file_listing_info

file_listing_info

=cut

sub file_listing_info {
    my ($self) = @_;
    my $params = $self->req->query_params->to_hash;
    $params->{sort} = [expand_csv($params->{sort} // "type,name")];
    return $params;
}

=head2 get_file

get_file

=cut

sub get_file {
    my ($self) = @_;
    my $file = $self->stash->{file_name};
    if (!valid_file_path($file)) {
       return $self->render_error(412, "invalid characters in file '$file'");
    }

    my $id = $self->id;
    my $path = findPath($id, $file);
    if (!defined $path) {
        return $self->render_error(404, "'$file' not found");
    }

    return $self->reply->file($path);
}

=head2 new_file

new_file

=cut

sub new_file {
    my ($self) = @_;
    my $file = $self->stash->{file_name};
    if (!valid_file_path($file)) {
       return $self->render_error(412, "invalid characters in file '$file'");
    }

    my $path = profileFilePath($self->id, $file);
    if (-e $path) {
       return $self->render_error(412, "'$file' already exists");
    }

    my $content = $self->req->body;
    eval {
        write_file($path, {no_clobber => 1}, $content);
    };
    if ($@) {
       return $self->render_error(422, "Error writing to the '$file'");
    }

    return $self->render(json => {});
}

=head2 replace_file

replace_file

=cut

sub replace_file {
    my ($self) = @_;
    my $file = $self->stash->{file_name};
    if (!valid_file_path($file)) {
       return $self->render_error(412, "invalid characters in file '$file'");
    }

    my $path = profileFilePath($self->id, $file);
    if (!-e $path) {
       return $self->render_error(412, "'$file' does not exists");
    }

    my $content = $self->req->body;
    eval {
        pf::util::safe_file_update($path, $content);
    };
    if ($@) {
       return $self->render_error(422, "Error writing to the '$file'");
    }

    return $self->render(json => {});
}


=head2 valid_file_path

valid_file_path

=cut

sub valid_file_path {
    my ($path) = @_;
    return $path !~ /(\/)?\.\.\//;
}


=head2 delete_path

delete_path

=cut

sub delete_file {
    my ($self) = @_;
    my $file = $self->stash->{file_name};
    if (!valid_file_path($file)) {
        return $self->render_error( 412, "invalid characters in file '$file'" );
    }

    my $path = profileFilePath( $self->id, $file );
    if (!unlink($path)) {
        if ($! == ENOENT()) {
            return $self->render_error(404, "'$file' not found");
        }

        $self->log->error("'$file': Error $!");
        return $self->render_error(422, "Error deleting '$file'");
    }

    return $self->render(json => {});
}

=head2 profileFilePath

profileFilePath

=cut

sub profileFilePath {
    my ($profile, $file) = @_;
    my $path = catfile($captiveportal_profile_templates_path, $profile, $file);
    return $path;
}

sub findPath {
    my ($profile, $file) = @_;
    return first { -f $_ } map { catfile($_, $file) } pathLookup($profile);
}

=head2 make_compare_functions

make_compare_functions

=cut

sub make_compare_functions {
    my ($sort_names) = @_;
    [map { make_compare_function($_) } @$sort_names];
}

=head2 make_compare_function

make_compare_function

=cut

sub make_compare_function {
    my ($order_by) = @_;
    my $direction = 'asc';
    if ($order_by =~ /^([^ ]+) (DESC|ASC)$/i ) {
       $order_by = $1;
       $direction = lc($2);
    }

    if ($direction eq 'desc') {
        return exists $NUMERICAL_SORTS{$order_by}
          ? make_num_rcmp($order_by)
          : make_string_rcmp($order_by);
    }

    return exists $NUMERICAL_SORTS{$order_by}
      ? make_num_cmp($order_by)
      : make_string_cmp($order_by);
}

=head2 profileFileListing

profileFileListing

=cut
sub profileFileListing {
    my ($id, $cmps) = @_;
    my $entries = mergePaths(pathLookup($id));
    sortEntry($entries, $cmps // [] );
    return $entries;
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

                    $data = { name => file_name($path), type => 'dir', size => 0, mtime => 0, entries => [] };
                }
                else {
                    return if file_excluded($path);
                    $data = makeFileInfo( $path, $full_path, $templateDir, @parentDirs );
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
    my ($short_path, $full_path, $templateDir, @parentPaths) = @_;
    my $stat = stat($full_path);
    return {
        type  => 'file',
        name  => file_name($short_path),
        size  => $stat->size,
        mtime => $stat->mtime,
        not_deletable => notDeletable($short_path, $full_path, $templateDir, @parentPaths),
        not_revertable => notRevertable($short_path, $full_path, $templateDir, @parentPaths),
    };
}

=head2 notDeletable

notDeletable

=cut

sub notDeletable {
    my ($short_path, $full_path, $templateDir, @parentPaths) = @_;
    return ( $full_path eq catfile( $templateDir, $short_path )
          && ( none { -f catfile( $_, $short_path ) } @parentPaths ) )
      ? json_false()
      : json_true();
}

sub notRevertable {
    my ($short_path, $full_path, $templateDir, @parentPaths) = @_;
    return ( $full_path eq catfile( $templateDir, $short_path )
          && ( any { -f catfile( $_, $short_path ) } @parentPaths ) )
      ? json_false()
      : json_true();
}

=head2 sortEntry

Sorts the dir entries by name

=cut

sub sortEntry {
    my ($root, $cmps) = @_;
    if ($root->{type} eq 'dir' && exists $root->{entries}) {
        my $entries = $root->{entries};
        foreach my $entry (@$entries) {
            if ($entry->{type} eq 'dir') {
                sortEntry($entry, $cmps);
            }
        }

        @$entries = sort { mcmp ($a, $b, $cmps) } @$entries;
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
