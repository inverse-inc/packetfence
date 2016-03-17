package pfappserver::PacketFence::Controller::Config::Profile;

=head1 NAME

pfappserver::PacketFence::Controller::Config::Profile add documentation

=cut

=head1 DESCRIPTION

PortalProfile

=cut

use strict;
use warnings;
use Moose;
use namespace::autoclean;
use File::Copy;
use HTTP::Status qw(:constants is_error is_success);
use File::Slurp qw(read_dir read_file write_file);
use File::Spec::Functions;
use File::Find;
use File::Copy::Recursive qw(dircopy);
use File::Basename qw(fileparse);
use Readonly;
use pf::cluster;
use pf::Portal::ProfileFactory;
use captiveportal::DynamicRouting::Application;
use pf::config;
use pf::util;
use pf::file_paths;
use List::Util qw(any);

Readonly our %FILTER_FILES =>
  (
   'redirect.tt' => 1,
   'response_wispr.tt' => 1,
   'wireless-profile.xml' => 1,
  );

BEGIN {
    extends 'pfappserver::Base::Controller';
}
with 'pfappserver::Base::Controller::Crud::Config' => {excludes => [qw(object)]};

__PACKAGE__->config(
    # Reconfigure the models and forms for actions
    action_args => {
        '*' => { model => "Config::Profile", form => 'Config::Profile'},
        'index' => { model => "Config::Profile", form => 'Portal'},
    },
    action => {
        # Configure access rights
        view   => { AdminRole => 'PORTAL_PROFILES_READ' },
        list   => { AdminRole => 'PORTAL_PROFILES_READ' },
        create => { AdminRole => 'PORTAL_PROFILES_CREATE' },
        update => { AdminRole => 'PORTAL_PROFILES_UPDATE' },
        remove => { AdminRole => 'PORTAL_PROFILES_DELETE' },
    },
);

=head1 METHODS

=head2 object

Portal Profile chained dispatcher

/config/profile/*

=cut

sub object :Chained('/') :PathPart('config/profile') :CaptureArgs(1) {
    my ($self, $c, $id) = @_;
    $self->_setup_object($c, $id);
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;
    $c->forward('list');
    if (is_success($c->response->status)) {
        my $model = $self->getModel($c);
        my $form =  $self->getForm($c);
        my $itemsKey = $model->itemsKey;
        my $items = $c->stash->{$itemsKey};
        $form->process(init_object => { $itemsKey => $items });
        $c->stash(form => $form);
    }
}

after create => sub {
    my ($self, $c) = @_;
    if (is_success($c->response->status) && $c->request->method eq 'POST') {
        my $model = $self->getModel($c);
        my $profile_dir = $self->_makeFilePath($c);
        mkdir($profile_dir);
        $c->response->location(
            $c->pf_hash_for(
                $c->controller('Config::Profile')->action_for('view'),
                [$c->stash->{$model->idKey}]
            )
        );
    }
};

sub sort_profiles :Local :Args(0) :AdminRole('PORTAL_PROFILES_READ') {
    my ($self, $c) = @_;
    $c->stash->{current_view} = 'JSON';
}

=head2 upload

Handles file uploads

=cut

sub upload :Chained('object') :PathPart('upload') :Args() :AdminRole('PORTAL_PROFILES_UPDATE') {
    my ($self, $c, @pathparts) = @_;
    $c->stash->{current_view} = 'JSON';
    $self->validatePathParts($c, @pathparts);
    my $upload = $c->request->upload('qqfile');
    my $file_name = $upload->filename;
    push @pathparts,$file_name;
    $c->stash->{path} = $file_name;
    $c->forward('path_exists');
    $self->validatePathParts($c, @pathparts);
    my $full_path = $self->_makeFilePath($c, @pathparts);
    $upload->copy_to($full_path);
    if ( $self->_sync_file( $c, $full_path) ) {
        $c->stash->{success} = 'true';
    }
}

=head2 validatePathParts

Validate all the path parts given to make sure no .. characaters are given

=cut

sub validatePathParts {
    my ($self, $c, @pathparts) = @_;
    if ( grep { /(\.\.)|[\/\0\?\*\+\%\$]/} @pathparts ) {
        $c->stash->{status_msg} = 'Invalid file name';
        $c->detach('bad_request');
    }
}

=head2 edit

Edit a file from the profile

=cut

sub edit :Chained('object') :PathPart :Args() :AdminRole('PORTAL_PROFILES_UPDATE') {
    my ($self, $c, @pathparts) = @_;
    my $full_file_name = catfile(@pathparts);
    my ($file_name,$directory) = fileparse($full_file_name);
    my $file_content = $self->getFileContent($c, $full_file_name);
    $directory = '' if $directory eq './';
    $directory = catfile($c->stash->{id}, $directory);
    $directory .= "/" unless $directory =~ /\/$/;
    $c->stash(
        file_name => $file_name,
        file_content => $file_content,
        directory => $directory,
        full_file_name => $full_file_name,
    );
}

=head2 getFileContent

Get the content of a file

=cut

sub getFileContent {
    my ($self, $c, $file_path) = @_;
    foreach my $dir ($self->mergedPaths($c)) {
        my $file = catfile($dir,$file_path);
        next unless -f $file;
        return read_file($file);
    }
    return;
}

=head2 edit_new

Create a new file in edit mode

=cut

sub edit_new :Chained('object') :PathPart :Args() :AdminRole('PORTAL_PROFILES_UPDATE') {
    my ($self, $c, @pathparts) = @_;
    $self->validatePathParts($c, @pathparts);
    my $full_file_name = catfile(@pathparts);
    my $file_path = $self->_makeFilePath($c, $full_file_name);
    my $file_content = '';
    if (-e $file_path) {
        $file_content = read_file($file_path);
    }
    elsif($full_file_name =~ /\.html$/) {
        $file_content = <<'HTML';
<!--- Your content here --->
HTML
    }
    my ($file_name, $directory) = fileparse($full_file_name);
    $c->stash(
        template => 'config/profile/edit.tt',
        file_name => $file_name,
        directory => $directory,
        full_file_name => $full_file_name,
        parent_dir => $file_name,
        file_content => $file_content
    );
}

=head2 rename

Rename a file

=cut

sub rename :Chained('object') :PathPart :Args() :AdminRole('PORTAL_PROFILES_UPDATE') {
    my ($self, $c,@pathparts) = @_;
    my $request = $c->request;
    my $to = $request->param('to');
    $self->validatePathParts($c, $to, @pathparts);
    my $from = catfile(@pathparts);
    my $from_path = $self->_makeFilePath($c, $from);
    my(undef, $directories, undef) = fileparse($from_path);
    my $to_path = catfile($directories, $to);
    $c->stash->{path} = $to_path;
    $c->forward('path_exists');
    move($from_path, $to_path);
    $c->stash->{current_view} = 'JSON';
    #verify file exists if it does set error
    pop @pathparts;
    $c->response->location( $c->pf_hash_for($c->controller('Config::Profile')->action_for('edit'), [$c->stash->{id}], catfile(@pathparts,$to)) );
}

=head2 new_file

Create a new file

=cut

sub new_file :Chained('object') :PathPart :Args() :AdminRole('PORTAL_PROFILES_UPDATE') {
    my ($self, $c, @pathparts) = @_;
    my $path = catfile(@pathparts);
    my $request = $c->request;
    if ($request->method eq 'POST') {
        my $file_name = $request->param('file_name');
        my $full_file_name = catfile(@pathparts, $request->param('file_name'));
        $c->stash->{current_view} = 'JSON';
        #verify file exists if it does set error
        $c->stash->{path} = $self->_makeFilePath($c, $full_file_name);;
        $c->forward('path_exists');
        $c->response->location( $c->pf_hash_for($c->controller('Config::Profile')->action_for('edit_new'), [$c->stash->{id} ],@pathparts, $file_name) );
    }
    else {
        $path .= "/" if $path ne '';
        $c->stash(path => $path);
    }

}

=head2 save

Save the contents of a file

=cut

sub save :Chained('object') :PathPart :Args() :AdminRole('PORTAL_PROFILES_UPDATE') {
    my ($self, $c, @pathparts) = @_;
    my $file_content = $c->req->param("file_content") || '';
    my $path = $self->_makeFilePath($c, @pathparts);
    $c->stash->{current_view} = 'JSON';
    write_file($path, $file_content);
    # Sync file in cluster if necessary
    $self->_sync_file($c, $path);
}

=head2 show_preview

Show the preview of a file

=cut

sub show_preview :Chained('object') :PathPart :Args() :AdminRole('PORTAL_PROFILES_READ') {
    my ($self, $c, @pathparts) = @_;
    my $file_name = catfile(@pathparts);
    $c->stash(file_name => $file_name);
}

=head2 preview

Preview a file

=cut

sub preview :Chained('object') :PathPart :Args() :AdminRole('PORTAL_PROFILES_READ') {
    my ($self, $c, @pathparts) = @_;
    my $template_path = $self->_makeFilePath($c);
    my $new_template = $self->_makePreviewTemplate($c, @pathparts);
    $self->add_fake_profile_data($c, $new_template, @pathparts);
    $c->stash(
              additional_template_paths => [$template_path],
              template => $new_template
             );
    my $profile = pf::Portal::ProfileFactory->instantiate("00:11:22:33:44:55", {portal => $c->stash->{id}});
    my $application = captiveportal::DynamicRouting::Application->new(
        session => {client_mac => $c->stash->{client_mac}, client_ip => $c->stash->{client_ip}},
        profile => $profile,
        request => $c->request,
        root_module_id => $profile->{_root_module},
    );

    $application->render($new_template, $c->stash);
    $c->response->body($application->template_output);
    $c->detach();

}

=head2 add_fake_profile_data

Add fake profile data for a preview

=cut

sub add_fake_profile_data {
    my ($self, $c, $template, @pathparts) = @_;
    $self->SUPER::add_fake_profile_data($c);
    if ($template eq 'remediation.html' && $pathparts[0] eq 'violations' ) {
        $c->stash( sub_template => catfile(@pathparts) );
    }
}

=head2 _makePreviewTemplate

A helper function for creating the template to be viewed

=cut

sub _makePreviewTemplate {
    my ($self, $c, @pathparts) = @_;
    my $template;
    if ($pathparts[0] eq 'violations') {
        $template = 'remediation.html';
    } else {
        my $file_content = read_file($self->_makeFilePath($c,@pathparts));
        $file_content =~ s/
            \[%\s*INCLUDE\s+\$[a-zA-Z_][a-zA-Z0-9_]+\s*%\]/
         <div>Your included template here<\/div>
        /x;
        $template = \$file_content;
    }
    return $template;
}

=head2 _makeFilePath

Make the file path for the current profile

=cut

sub _makeFilePath {
    my ($self, $c, @pathparts) = @_;
    return catfile($CAPTIVE_PORTAL{PROFILE_TEMPLATE_DIR},$c->stash->{id}, @pathparts);
}

=head2 mergedPaths

Returns all the merge paths

=cut

sub mergedPaths {
    my ($self, $c) = @_;
    return (catfile($captiveportal_profile_templates_path, $c->stash->{id}), $self->parentPaths($c));
}

=head2 parentPaths

Return the parent paths

=cut

sub parentPaths {
    return ($captiveportal_default_profile_templates_path, $captiveportal_templates_path);
}

=head2 _makeDefaultFilePath

Create the path of the standard packetfence temnplate

=cut

sub _makeDefaultFilePath {
    my ($self, $c, @pathparts) = @_;
    return catfile($CAPTIVE_PORTAL{TEMPLATE_DIR}, @pathparts);
}

=head2 delete_file

Delete file a from the profile

=cut

sub delete_file :Chained('object') :PathPart('delete') :Args() :AdminRole('PORTAL_PROFILES_UPDATE') {
    my ($self, $c, @pathparts) = @_;

    $c->stash->{current_view} = 'JSON';

    if($cluster_enabled){
        $c->response->status(HTTP_NOT_IMPLEMENTED);
        $c->stash->{status_msg} = "Cannot delete a file in cluster mode. Please use the command line to remove it from each server.";
        $c->detach;
    }

    my $file_path = $self->_makeFilePath($c, @pathparts);
    unlink($file_path);
}

=head2 revert_file

Revert a file from the filesystem

=cut

sub revert_file :Chained('object') :PathPart :Args() :AdminRole('PORTAL_PROFILES_UPDATE') {
    my ($self, $c, @pathparts) = @_;
    $c->stash->{current_view} = 'JSON';
    my $file_path = $self->_makeFilePath($c,@pathparts);
    my $default_file_path = $self->_makeDefaultFilePath($c, @pathparts);
    copy($default_file_path, $file_path);
    # Sync file in cluster if necessary
    $self->_sync_file($c, $file_path);
}

=head2 files

Display all the files

=cut

sub files :Chained('object') :PathPart :Args(0) :AdminRole('PORTAL_PROFILES_READ') {
    my ($self, $c) = @_;
    $c->stash(root => $self->mergeFilesFromPaths($c, $self->mergedPaths($c)));
}

=head2 path_exists

Checks to see if the path exists

=cut

sub path_exists :Private {
    my ($self, $c) = @_;
    if (-e $c->stash->{path}) {
        $c->stash(status_msg => 'File already exist');
        $c->detach('bad_request');
    }
}

=head2 copy_file

Copy files from one path to another

=cut

sub copy_file :Chained('object'): PathPart('copy'): Args() :AdminRole('PORTAL_PROFILES_UPDATE') {
    my ($self, $c, @pathparts) = @_;
    my $from = catfile(@pathparts);
    my $request = $c->request;
    if ($request->method eq 'POST') {
        my $to = $request->param('to');
        $self->validatePathParts($c, $to, @pathparts);
        my $from_path = $self->_makeFilePath($c,$from);
        my (undef, $directories, undef) = fileparse($from_path);
        my $to_path = catfile($directories, $to);
        $c->stash->{path} = $to_path;
        $c->forward('path_exists');
        $c->stash->{current_view} = 'JSON';
        copy($from_path, $to_path);
        # Sync file in cluster if necessary
        $self->_sync_file($c, $to_path);
    }
    else {
        my (undef, $path, undef) = fileparse($from);
        $path = '' if $path eq './';
        $c->stash(
            from => $from,
            path => $path
        );
    }
}

=head2 isPreviewable

Check to see if a file is previewable

=cut

sub isPreviewable {
    my ($self, $file_name) = @_;
    return $file_name =~ /\.html$/;
}

=head2 isDeleteOrRevertDisabled

Checks to see of a file show the delete or revert button

=cut

sub isDeleteOrRevertDisabled {
    return 0;
}


=head2 isEditable

Checks to see if a file is editable

=cut

sub isEditable {
    my ($self, $file_name) = @_;
    if ($file_name =~ /\.html$/) {
        return 1;
    }
    return 0;
}

=head2 revert_all

Revert all the files

=cut

sub revert_all :Chained('object') :PathPart :Args(0) :AdminRole('PORTAL_PROFILES_UPDATE') {
    my ($self,$c) = @_;

    $c->stash->{current_view} = 'JSON';
    if($cluster_enabled){
        $c->response->status(HTTP_NOT_IMPLEMENTED);
        $c->stash->{status_msg} = "Cannot revert all files in cluster mode. Please use the command line to copy the files from the default profile or revert files individually.";
        $c->detach;
    }

    my ($local_result, $failed_syncs) = $self->copyDefaultFiles($c);

    my $status_msg = "Copied " . ($local_result->{entries_copied} - $local_result->{dir_copied}) . " files";
    $c->stash->{status_msg} = $status_msg;
}

=head2 copyDefaultFiles

Copy the standard packetfence to the profile

=cut

sub copyDefaultFiles {
    my ($self, $c) = @_;
    my $to_dir = $self->_makeFilePath($c);
    my $from_dir = $self->_makeDefaultFilePath($c);
    my $local_result = {};
    ($local_result->{entries_copied}, $local_result->{dir_copied}, undef) = dircopy($from_dir, $to_dir);
    my $failed_syncs = pf::cluster::send_dir_copy($from_dir, $to_dir);

    return ($local_result, $failed_syncs);
}

=head2 _sync_file

Sync a file to the other cluster members if configured to do so (cluster enabled)

=cut

sub _sync_file {
    my ($self, $c, $file) = @_;
    if($cluster_enabled){
        $c->log->info("Synching $file in cluster");
        my $failed = pf::cluster::sync_files([$file]);
        if(@$failed){
            $c->response->status(HTTP_INTERNAL_SERVER_ERROR);
            $c->stash->{status_msg} = "Failed to sync file on ".join(', ', @$failed);
            return $FALSE;
        }
    }
    return $TRUE;
}

=head2 mergeFilesFromPaths

Create a merged directory tree of the directories given

=cut

sub mergeFilesFromPaths {
    my ($self, $c, @dirs) = @_;
    my %paths;
    my $root;
    my @paths;
    find({
        wanted => sub {
                my $full_path = my $path = $_;
                #Just get the file path minus the parent directory
                $path =~ s/^\Q$File::Find::topdir\E\/?//;
                return if exists $paths{$path};
                my $dir = $File::Find::dir;
                #Just get the directory path minus the parent directory
                $dir =~ s/^\Q$File::Find::topdir\E\/?//;
                my $data;
                if (-d) {
                    $data = { name => $path, type => 'dir' , size => 0, entries => [] };
                    push @paths, $data;
                } else {
                    $data = $self->makeFileInfo($path,$full_path);
                }
                $paths{$path} = $data;
                if($path ne '') {
                    push @{ $paths{$dir}{entries} }, $data;
                } else {
                    $root = $data;
                }
            },
            no_chdir => 1
        }, @dirs);
    sortEntry($root);
    return $root;
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
        @$entries = sort { $a->{name} cmp $b->{name} } @$entries;
    }
}


=head2 makeFileInfo

Create a hash with the file information

=cut


sub makeFileInfo {
    my ($self, $short_path, $full_path) = @_;
    my %data = (
        name => $short_path,
        full_path => $full_path,
        type => 'file',
        size => format_bytes(-s $full_path),
        editable => $self->isEditable($full_path),
        previewable => $self->isPreviewable($full_path),
        delete_or_revert_disabled => $self->isDeleteOrRevertDisabled($short_path),
        delete_or_revert => $self->revertableOrDeletable($short_path),
    );
    return \%data;
}


=head2 revertableOrDeletable

Checks to see if the file is deletable or revertable

=cut

sub revertableOrDeletable {
    my ($self, $path) = @_;
    return ( any { -f catfile($_,$path) } $self->parentPaths ) ? 'revert' : 'delete';
}


=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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

