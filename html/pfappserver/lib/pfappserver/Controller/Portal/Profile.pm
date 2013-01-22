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
use File::Slurp qw(read_dir read_file);
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

    my $pf_config = $c->model('Config::Pf');
    my $profile = $pf_config->_get_section_group('portal-profile',$name);

    if (defined $profile) {
        $c->stash->{profile_name} = $name;
        $c->stash->{profile} = $profile;
    }
    else {
        $c->response->status(HTTP_NOT_FOUND);
        $c->stash->{status_msg} = $c->loc('The profile was not found.');
        $c->stash->{current_view} = 'JSON';
        $c->detach();
    }
}

=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my ($profiles, $form);
    my $pf_config = $c->model('Config::Pf');
    $profiles = $pf_config->_get_all_section_group('portal-profile');
    $form = new pfappserver::Form::Portal(ctx => $c,
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

sub _get_form {
    my ($self,$c,@args) = @_;
    return pfappserver::Form::Portal::Profile->new(ctx => $c,@args);
}

sub update :Chained('object') :PathPart('update') :Args(0) {
    my ($self,$c) = @_;
    my ($status,$status_msg,$form);
    $c->stash->{current_view} = 'JSON';
    $form = $self->_get_form();
    $form->process(params => $c->request->params);
    if ($form->has_errors) {
        $status = HTTP_BAD_REQUEST;
        $status_msg = $form->field_errors;
    }
    else {
        ($status,$status_msg) = $self->_update_profile($c,$form);
    }

    $c->response->status($status);
    $c->stash->{status_msg} = $status_msg; # TODO: localize error message
}

sub _update_profile {
    my ($self,$c,$form) = @_;
    my $pf_config = $c->model('Config::Pf');
    my $profile = $form->value;
    my $id = $profile->{id};
    delete $profile->{id};
    if($pf_config->_update_section_group("portal-profile",$id,$profile)) {
    }
    return (HTTP_OK,"");
}

sub upload :Chained('object') :PathPart('upload') :Args() {
    my ($self,$c,@pathparts) = @_;

    $c->stash->{current_view} = 'JSON';
    $c->stash->{success} = 'true';
    my $upload = $c->request->upload('qqfile');
    my $file_name = $upload->filename;
    push @pathparts,$file_name;
    $self->validate_path_parts($c,@pathparts);

    $upload->copy_to($self->_make_file_path($c,@pathparts));
}

sub validate_path_parts {
    my ($self,$c,@pathparts) = @_;
}

sub edit :Chained('object') :PathPart :Args() {
    my ($self,$c,@pathparts) = @_;
    my $file_name = catfile(@pathparts);
    my $file_path = $self->_make_file_path($c,$file_name);
    my $file_content = read_file($file_path);
    $c->stash(
        file_name => $file_name,
        file_content => $file_content
    );
}

sub edit_new :Chained('object') :PathPart :Args() {
    my ($self,$c,@pathparts) = @_;
    my $file_name = catfile(@pathparts);
    my $file_path = $self->_make_file_path($c,$file_name);
    my $file_content = '';
    if (-e $file_path) {
        $file_content = read_file($file_path);
    }
    elsif($file_name =~ /\.html$/) {
        $file_content = <<'HTML';
[% title = i18n("New File Title") %]
[% INCLUDE header.html %]

[% INCLUDE footer.html %]
HTML
    }
    $c->stash(
        template => 'portal/profile/edit.tt',
        file_name => $file_name,
        file_content => $file_content
    );
}


sub rename :Chained('object') :PathPart :Args() {
    my ($self,$c,@pathparts) = @_;
    my $from = catfile(@pathparts);
    my $request = $c->request;
    my $new_file_name = $request->param('to');
    my $from_path = $self->_make_file_path($c,$from);
    my(undef, $directories, undef) = fileparse($from_path);
    my $to_path = catfile($directories,$new_file_name);
    $c->stash->{path} = $to_path;
    $c->forward('path_exists');
    move($from_path,$to_path);
    $c->stash->{current_view} = 'JSON';
    #verify file exists if it does set error
    $c->response->location( $c->pf_hash_for($c->controller('Portal::Profile')->action_for('edit'), [$c->stash->{profile_name} ], $new_file_name ));
}

sub new_file :Chained('object') :PathPart :Args() {
    my ($self,$c,@pathparts) = @_;
    my $path = catfile(@pathparts);
    my $request = $c->request;
    if ($request->method eq 'POST') {
        my $file_name = catfile(@pathparts,$request->param('file_name'));
        $c->stash->{current_view} = 'JSON';
        #verify file exists if it does set error
        $c->stash->{path} = $self->_make_file_path($c,$file_name);;
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
    my $file_name = catfile(@pathparts);
    my $file_path = $self->_make_file_path($c,$file_name);
    my $file_content = $c->req->param("file_content") || '';
    use Data::Dumper;
    $c->log->info(Dumper( $c->req->params));
    $c->stash->{current_view} = 'JSON';

    local(*FILE);
    open(FILE,">$file_path");
    print FILE $file_content;
    close(FILE);
}

sub _make_file_path {
    my ($self,$c,@pathparts) = @_;
    return catfile($CAPTIVE_PORTAL{PROFILE_TEMPLATE_DIR},$c->stash->{profile_name},@pathparts);
}

sub _make_default_file_path {
    my ($self,$c,@pathparts) = @_;
    return catfile($CAPTIVE_PORTAL{TEMPLATE_DIR},@pathparts);
}


sub delete_file :Chained('object') :PathPart('delete') :Args() {
    my ($self,$c,@pathparts) = @_;
    $c->stash->{current_view} = 'JSON';
    my $file_path = $self->_make_file_path($c,@pathparts);
    unlink($file_path);
}

sub revert_file :Chained('object') :PathPart :Args() {
    my ($self,$c,@pathparts) = @_;
    $c->stash->{current_view} = 'JSON';
    my $file_path = $self->_make_file_path($c,@pathparts);
    my $default_file_path = $self->_make_default_file_path($c,@pathparts);
    copy($default_file_path,$file_path);
}

sub filter_entries {
    my ($regex,@entries);
}

sub view :Chained('object') :PathPart('') :Args(0) {
    my ($self,$c) = @_;
    $c->stash(
        profile_form  => $self->_get_form($c,init_object => $c->stash->{profile}),
    );
}

sub files :Chained('object') :PathPart :Args(0) {
    my ($self,$c) = @_;
    $c->stash(
        $self->_get_files_info($c)
    );
}

sub _get_files_info {
    my ($self,$c) = @_;
    my $profile = $c->stash->{profile_name};
    my $root_path = $self->_make_file_path($c);
    my %default_files =
        map { catfile($root_path,$_) => 1 }
        _read_dir_recursive($self->_make_default_file_path($c));
    my @files =
            map {$self->_make_file_info( $root_path, $_, \%default_files)}
            sort grep { !exists $FILTER_FILES{$_}  } read_dir($root_path);


    return (files => \@files);
}

sub path_exists :Private {
    my ($self,$c) = @_;
    if(-e $c->stash->{path}) {
        $c->stash(
            status_msg => 'File already exist'
        );
        $c->go('bad_request');
        $c->detach();
    }
}

sub copy_file :Chained('object'): PathPart('copy'): Args() {
    my ($self,$c,@pathparts) = @_;
    my $from = catfile(@pathparts);
    my $request = $c->request;
    if ($request->method eq 'POST') {
        my $to = $request->param('to');
        my $from_path = $self->_make_file_path($c,$from);
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

sub _make_file_info {
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
            map {$self->_make_file_info($full_path,$_,$default_files) }
            sort  (read_dir($full_path))
        ];
    }
    else {
        $data{'editable'} = is_editable($full_path);
        $data{'delete_or_revert'} =  (
                (exists $default_files->{$full_path}  ) ?
                'revert' :
                'delete'
        );
        $data{'delete_or_revert_disabled'} = $self->is_delete_or_revert_disabled();
    }
   return \%data;
}

sub is_delete_or_revert_disabled {
    return 0;
}

sub is_editable {
    my ($file_name) = @_;
    if( $file_name =~ /\.html$/ ) {
        return 1;
    }
    return 0;
}

sub _read_dir_recursive {
    my ($path,@subdir) = @_;
    my @files;
    my $root_path = catfile($path,@subdir);
    foreach my $entry (read_dir($root_path)) {
        my $full_path = catfile($root_path,$entry);
        if (-d $full_path) {
            push @files, map {catfile(@subdir,$entry,$_) } _read_dir_recursive($path,@subdir,$entry);
        }
        else {
            push @files, $entry;
        }
    }
    return @files;
}

sub revert_all :Chained('object') :PathPart :Args(0) {
    my ($self,$c) = @_;
    $c->stash->{current_view} = 'JSON';
    my $to_dir = $self->_make_file_path($c);
    my $from_dir = $CAPTIVE_PORTAL{TEMPLATE_DIR};
    my($entries_copied,$dir_copied,undef) = dircopy($from_dir,$to_dir);
    my $status_msg = "Copied " . ($entries_copied - $dir_copied) . " files";
    $c->stash->{status_msg} = $status_msg;
}

sub delete_profile :Chained('object') :PathPart('delete') :Args(0) {
    my ($self,$c) = @_;
    $c->stash->{current_view} = 'JSON';
    my $pf_config = $c->model('Config::Pf');
    $pf_config->_delete_section_group('portal-profile',$c->stash->{profile_name});
    $c->stash->{status_msg} = "Deleted the " . $c->stash->{profile_name}  . " profile";
}

sub create : Local: Args(0) {
    my ($self,$c) = @_;
    if ($c->request->method eq 'POST') {
        # check if exists
        # Create the source from the update action
        my $id = $c->req->param('id');
        $c->stash->{profile_name} = $id;
        $c->forward('update');
        $c->forward('revert_all');
        my $uri = $c->uri_for($c->controller('Admin')->action_for('configuration'));
        my $redirect = "$uri" . $c->pf_hash_for($c->controller('Portal::Profile')->action_for('read'),[$id]);
        $c->log->info("redirect : $redirect");
        $c->response->redirect($redirect);
    }
    else {
        # Show an empty form
        $c->stash->{profile} = {};
        $c->forward('read');
    }
}

=back

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

