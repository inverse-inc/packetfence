package pfappserver::Controller::Portal::Profile;
=head1 NAME

pfappserver::Controller::PortalProfile add documentation

=cut

=head1 DESCRIPTION

PortalProfile

=cut

use strict;
use warnings;
use Moose;
use namespace::autoclean;
use pfappserver::Form::Portal::Profile;
use pfappserver::Form::Portal;
use pf::Portal::ProfileFactory;
use pf::config;
use File::Copy;
use HTTP::Status qw(:constants is_error is_success);
use pf::util;
use File::Slurp qw(read_dir read_file write_file);
use File::Spec::Functions;
use File::Copy::Recursive qw(dircopy);
use File::Basename qw(fileparse);
use Readonly;

Readonly our %FILTER_FILES => (
    'redirection.tt' => 1,
    'response_wispr.tt' => 1,
    'wireless-profile.xml' => 1,
);

BEGIN { extends 'pfappserver::Base::Controller::Base'; }

=head2 object

Authentication source chained dispatcher

/portal/profile/*

=cut

sub object :Chained('/') :PathPart('portal/profile') :CaptureArgs(1) {
    my ($self, $c, $name) = @_;
    my $model = $self->getConfigModel($c);
    my ($status,$result_or_msg) = $model->read($name);
    if (is_success($status)) {
        $c->stash(
            profile_name => $name,
            profile => $result_or_msg,
            model => $model
        );
    } else {
        $c->stash(
            current_view => 'JSON',
            status_msg => $result_or_msg,
        );
    }
    $c->response->status($status);
}

=head2 getConfigModel

=cut
sub getConfigModel {
    my ( $self, $c ) = @_;
    return $c->model('Config::Profiles');
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my $config = $self->getConfigModel($c);
    my ($status,$profiles) = $config->read_all();
    my $form = new pfappserver::Form::Portal(ctx => $c,
                                                init_object => { profiles => $profiles });
    $form->process();
    $c->stash(
        form => $form,
    )
}

sub sort_profiles :Local : Args(0) {
    my ($self,$c) = @_;
    $c->stash->{current_view} = 'JSON';
}

sub getForm {
    my ($self,$c,@args) = @_;
    return pfappserver::Form::Portal::Profile->new(ctx => $c,@args);
}

sub update :Chained('object') :PathPart('update') :Args(0) {
    my ($self,$c) = @_;
    my ($status,$status_msg,$form);
    $c->stash->{current_view} = 'JSON';
    $form = $self->getForm();
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $status_msg = $form->field_errors;
    } else {
        ($status,$status_msg) = $c->stash->{model}->updateItem(
            $c->stash->{profile_name},
            $form->value
        );
    }

    $c->response->status($status);
    $c->stash->{status_msg} = $status_msg; # TODO: localize error message
}

sub upload :Chained('object') :PathPart('upload') :Args() {
    my ($self,$c,@pathparts) = @_;
    $c->stash->{current_view} = 'JSON';
    $self->validatePathParts($c,@pathparts);
    $c->stash->{success} = 'true';
    my $upload = $c->request->upload('qqfile');
    my $file_name = $upload->filename;
    push @pathparts,$file_name;
    $c->stash->{path} = $file_name;
    $c->forward('path_exists');
    $self->validatePathParts($c,@pathparts);
    $upload->copy_to($self->_makeFilePath($c,@pathparts));
}

sub validatePathParts {
    my ($self,$c,@pathparts) = @_;
    if ( grep { /(\.\.)|[\/\0\?\*\+\%]/} @pathparts   ) {
        $c->stash->{status_msg} = 'Invalid file name';
        $c->detach('bad_request');
    }
}

sub edit :Chained('object') :PathPart :Args() {
    my ($self,$c,@pathparts) = @_;
    my $full_file_name = catfile(@pathparts);
    my ($file_name,$directory) = fileparse($full_file_name);
    my $file_path = $self->_makeFilePath($c,$full_file_name);
    my $file_content = read_file($file_path);
    $directory = '' if $directory eq './';
    $directory = catfile($c->stash->{profile_name},$directory);
    $c->stash(
        file_name => $file_name,
        file_content => $file_content,
        directory => $directory,
        full_file_name => $full_file_name,
    );
}

sub edit_new :Chained('object') :PathPart :Args() {
    my ($self,$c,@pathparts) = @_;
    $self->validatePathParts($c,@pathparts);
    my $full_file_name = catfile(@pathparts);
    my $file_path = $self->_makeFilePath($c,$full_file_name);
    my $file_content = '';
    if (-e $file_path) {
        $file_content = read_file($file_path);
    }
    elsif($full_file_name =~ /\.html$/) {
        $file_content = <<'HTML';
[% title = i18n("New File Title") %]
[% INCLUDE header.html %]

[% INCLUDE footer.html %]
HTML
    }
    my ($file_name,$directory) = fileparse($full_file_name);
    $c->stash(
        template => 'portal/profile/edit.tt',
        file_name => $file_name,
        directory => $directory,
        full_file_name => $full_file_name,
        parent_dir => $file_name,
        file_content => $file_content
    );
}

sub rename :Chained('object') :PathPart :Args() {
    my ($self,$c,@pathparts) = @_;
    my $request = $c->request;
    my $to = $request->param('to');
    $self->validatePathParts($c,$to,@pathparts);
    my $from = catfile(@pathparts);
    my $from_path = $self->_makeFilePath($c,$from);
    my(undef, $directories, undef) = fileparse($from_path);
    my $to_path = catfile($directories,$to);
    $c->stash->{path} = $to_path;
    $c->forward('path_exists');
    move($from_path,$to_path);
    $c->stash->{current_view} = 'JSON';
    #verify file exists if it does set error
    $c->response->location( $c->pf_hash_for($c->controller('Portal::Profile')->action_for('edit'), [$c->stash->{profile_name} ], $to ));
}

sub new_file :Chained('object') :PathPart :Args() {
    my ($self,$c,@pathparts) = @_;
    my $path = catfile(@pathparts);
    my $request = $c->request;
    if ($request->method eq 'POST') {
        my $file_name = catfile(@pathparts,$request->param('file_name'));
        $c->stash->{current_view} = 'JSON';
        #verify file exists if it does set error
        $c->stash->{path} = $self->_makeFilePath($c,$file_name);;
        $c->forward('path_exists');
        $c->response->location( $c->pf_hash_for($c->controller('Portal::Profile')->action_for('edit_new'), [$c->stash->{profile_name} ], $file_name ));
    }
    else {
        $path .= "/" if $path ne '';
        $c->stash(
            path => $path
        );
    }

}

sub save :Chained('object') :PathPart :Args() {
    my ($self,$c,@pathparts) = @_;
    my $file_content = $c->req->param("file_content") || '';
    my $path = $self->_makeFilePath($c,@pathparts);
    $c->stash->{current_view} = 'JSON';
    write_file($path,$file_content);
}

sub show_preview :Chained('object') :PathPart :Args() {
    my ($self,$c,@pathparts) = @_;
    my $file_name = catfile(@pathparts);
    $c->stash(
        file_name => $file_name
    );
}

sub preview :Chained('object') :PathPart :Args() {
    my ($self,$c,@pathparts) = @_;
    my $template_path = $self->_makeFilePath($c);
    my $file_name = catfile(@pathparts);
    $self->add_fake_profile_data($c);
    $c->stash(
        additional_template_paths => [$template_path],
        template => $file_name
    );
}

sub _makeFilePath {
    my ($self,$c,@pathparts) = @_;
    return catfile($CAPTIVE_PORTAL{PROFILE_TEMPLATE_DIR},$c->stash->{profile_name},@pathparts);
}

sub _makeDefaultFilePath {
    my ($self,$c,@pathparts) = @_;
    return catfile($CAPTIVE_PORTAL{TEMPLATE_DIR},@pathparts);
}


sub delete_file :Chained('object') :PathPart('delete') :Args() {
    my ($self,$c,@pathparts) = @_;
    $c->stash->{current_view} = 'JSON';
    my $file_path = $self->_makeFilePath($c,@pathparts);
    unlink($file_path);
}

sub revert_file :Chained('object') :PathPart :Args() {
    my ($self,$c,@pathparts) = @_;
    $c->stash->{current_view} = 'JSON';
    my $file_path = $self->_makeFilePath($c,@pathparts);
    my $default_file_path = $self->_makeDefaultFilePath($c,@pathparts);
    copy($default_file_path,$file_path);
}

sub view :Chained('object') :PathPart('') :Args(0) {
    my ($self,$c) = @_;
    $c->stash(
        profile_form  => $self->getForm($c,init_object => $c->stash->{profile}),
    );
}

sub files :Chained('object') :PathPart :Args(0) {
    my ($self,$c) = @_;
    $c->stash(
        root => $self->_getFilesInfo($c)
    );
}

sub _getFilesInfo {
    my ($self,$c) = @_;
    my $profile = $c->stash->{profile_name};
    my $root_path = $self->_makeFilePath($c);
    my %default_files =
        map { catfile($root_path,$_) => 1 }
        _readDirRecursive($self->_makeDefaultFilePath($c));
    my %root = (
        'type'   => 'dir',
        'name' => $profile,
        'entries' => [
            map {$self->_makeFileInfo( $root_path, $_, \%default_files)}
            sort grep { !exists $FILTER_FILES{$_} && !m/^\./ } read_dir($root_path)],
        'hidden' => 0,
        'size'   => 0,
    );
    return \%root;
}

sub path_exists :Private {
    my ($self,$c) = @_;
    if(-e $c->stash->{path}) {
        $c->stash(
            status_msg => 'File already exist'
        );
        $c->detach('bad_request');
    }
}

sub copy_file :Chained('object'): PathPart('copy'): Args() {
    my ($self,$c,@pathparts) = @_;
    my $from = catfile(@pathparts);
    my $request = $c->request;
    if ($request->method eq 'POST') {
        my $to = $request->param('to');
        $self->validatePathParts($c,$to,@pathparts);
        my $from_path = $self->_makeFilePath($c,$from);
        my(undef, $directories, undef) = fileparse($from_path);
        my $to_path = catfile($directories,$to);
        $c->stash->{path} = $to_path;
        $c->forward('path_exists');
        $c->stash->{current_view} = 'JSON';
        copy($from_path,$to_path);
    }
    else {
        my(undef, $path, undef) = fileparse($from);
        $path = '' if $path eq './';
        $c->stash(
            from => $from,
            path => $path
        );
    }
}

sub _makeFileInfo {
    my ($self,$root_path,$file_name,$default_files) = @_;
    my $full_path = catfile($root_path,$file_name);
    my $i = 0;
    my %data = (
        name => $file_name,
        size => format_bytes( -s $full_path),
        hidden => 1,
    );
    if( -d $full_path) {
        $data{'type'} = 'dir';
        $data{'entries'} = [
            grep { $_->{name} = catfile($file_name,$_->{name}) }
            map {$self->_makeFileInfo($full_path,$_,$default_files) }
            sort grep { !m/^\./ } (read_dir($full_path))
        ];
    }
    else {
        $data{'editable'} = $self->isEditable($full_path);
        $data{'delete_or_revert'} =  (
                (exists $default_files->{$full_path}  ) ?
                'revert' :
                'delete'
        );
        $data{'delete_or_revert_disabled'} = $self->isDeleteOrRevertDisabled($full_path);
        $data{'previewable'} = $self->isPreviewable($full_path);
    }
   return \%data;
}
sub isPreviewable {
    my ($self,$file_name) = @_;
    return $file_name =~ /\.html$/;
}
sub isDeleteOrRevertDisabled {
    return 0;
}

sub isEditable {
    my ($self,$file_name) = @_;
    if( $file_name =~ /\.html$/ ) {
        return 1;
    }
    return 0;
}

sub _readDirRecursive {
    my ($path,@subdir) = @_;
    my @files;
    my $root_path = catfile($path,@subdir);
    foreach my $entry (read_dir($root_path)) {
        my $full_path = catfile($root_path,$entry);
        if (-d $full_path) {
            push @files, map {catfile(@subdir,$entry,$_) } _readDirRecursive($path,@subdir,$entry);
        }
        elsif ($entry !~ m/^\./) {
            push @files, $entry;
        }
    }
    return @files;
}

sub revert_all :Chained('object') :PathPart :Args(0) {
    my ($self,$c) = @_;
    $c->stash->{current_view} = 'JSON';
    my($entries_copied,$dir_copied,undef) = $self->copyDefaultFiles($c);
    my $status_msg = "Copied " . ($entries_copied - $dir_copied) . " files";
    $c->stash->{status_msg} = $status_msg;
}

sub copyDefaultFiles {
    my ($self,$c) = @_;
    my $to_dir = $self->_makeFilePath($c);
    my $from_dir = $self->_makeDefaultFilePath($c);
    return dircopy($from_dir,$to_dir);
}

sub delete_profile :Chained('object') :PathPart('delete') :Args(0) {
    my ($self,$c) = @_;
    $c->stash->{current_view} = 'JSON';
    my ($status,$status_msg) = $c->stash->{model}->deleteItem(
        $c->stash->{profile_name}
    );
    $c->stash(
        status_msg => $status_msg
    );
    $c->response->status($status);
}

sub create : Local: Args(0) {
    my ($self,$c) = @_;
    if ($c->request->method eq 'POST') {
        $c->stash( current_view => 'JSON');
        my ($status,$status_msg);
        my $form = $self->getForm();
        $form->process(params => $c->request->params);
        if ($form->has_errors) {
            $status = HTTP_BAD_REQUEST;
            $status_msg = $form->field_errors;
        }
        else {
            my $id = $c->req->param('id');
            my $model = $self->getConfigModel($c);
            $c->stash->{profile_name} = $id;
            ($status,$status_msg) = $model->createItem(
                $id,
                $form->value
            );
            if(is_success($status)) {
                my($entries_copied,$dir_copied,undef) = $self->copyDefaultFiles($c);
                $c->response->location(
                    $c->pf_hash_for(
                        $c->controller('Portal::Profile')->action_for('view'),
                        [$id]
                    )
                );
            }
            $c->response->status($status);
        }
        $c->stash->{status_msg} = $status_msg;
        # check if exists
        # Create the source from the update action
    }
    else {
        # Show an empty form
        $c->stash->{profile} = {};
        $c->forward('view');
    }
}

=back

=head1 COPYRIGHT

Copyright (C) 2012-2013 Inverse inc.

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

