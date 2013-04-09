package pfappserver::Controller::Portal::Profile::Default;
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
use pfappserver::Form::Portal::Profile::Default;
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

BEGIN { extends 'pfappserver::Controller::Portal::Profile'; }


=head2 Methods

=over

=item index

=cut

sub index {}


sub begin :Private {
    my ( $self, $c ) = @_;
    $c->stash->{current_model_instance} = $c->model("Config::Profile::Default");
    $c->stash->{current_form_instance} = $c->form("Portal::Profile::Default")->new(ctx=>$c);
}


=item isDeleteOrRevertDisabled

=cut

sub isDeleteOrRevertDisabled {return 1};

=item object

The default chained dispatcher

/portal/profile/default

=cut

sub object :Chained('/') :PathPart('portal/profile/default') :CaptureArgs(0) {
    my ($self, $c) = @_;
    my $result = $self->SUPER::object($c,'default');
    my $profile = $c->stash->{item};
    if ($profile) {
        @{$profile}{'id','description'} = ( 'default', 'The Default Profile');
    }
    return $result;
}

=item get_form

=cut

sub getForm {
    my ($self,$c,@args) = @_;
    return pfappserver::Form::Portal::Profile::Default->new(ctx => $c,@args);
}

=item _make_file_path

=cut

sub _makeFilePath {
    my ($self,@args) = @_;
    return $self->_makeDefaultFilePath(@args);
}

=item delete_file

=cut

sub delete_file :Chained('object') :PathPart('delete') :Args() {
    my ($self,$c,@pathparts) = @_;
    $c->stash->{status_msg} = "Cannot delete a file in the default profile";
    $c->go('bad_request');
}

=item revert_file

=cut

sub revert_file :Chained('object') :PathPart :Args() {
    my ($self,$c,@pathparts) = @_;
    $c->stash->{status_msg} = "Cannot revert a file in the default profile";
    $c->go('bad_request');
}

=item revert_all

=cut

sub revert_all :Chained('object') :PathPart :Args(0) {
    my ($self,$c) = @_;
    $c->stash->{status_msg} = "Cannot revert files in the default profile";
    $c->go('bad_request');
}

=item delete_profile

=cut

sub remove :Chained('object') :PathPart :Args(0) {
    my ($self,$c) = @_;
    $c->stash->{status_msg} = "Cannot delete the default profile";
    $c->go('bad_request');
}

=item end

=cut

sub end : ActionClass('RenderView') {
    my ($self,$c) = @_;
    if(! exists($c->stash->{template})) {
        $c->stash(
            template => 'portal/profile/' . $c->action->name . '.tt'
        );
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

