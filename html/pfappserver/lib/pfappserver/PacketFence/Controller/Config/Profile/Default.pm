package pfappserver::PacketFence::Controller::Config::Profile::Default;

=head1 NAME

pfappserver::Controller::ConfigProfile add documentation

=cut

=head1 DESCRIPTION

PortalProfile

=cut

use strict;
use warnings;
use Moose;
use namespace::autoclean;
use pf::config;
use File::Copy;
use HTTP::Status qw(:constants is_error is_success);
use pf::util;
use File::Slurp qw(read_dir read_file);
use File::Spec::Functions;
use File::Copy::Recursive qw(dircopy);
use File::Basename qw(fileparse);
use Readonly;

BEGIN { extends 'pfappserver::Controller::Config::Profile'; }

__PACKAGE__->config(
    # Configure the model and the form for actions
    action_args => {
        '*' => { model => "Config::Profile", form => 'Config::Profile::Default'},
    },
    action => {
        # Configure access rights
        view   => { AdminRole => 'PORTAL_PROFILES_READ' },
        list   => { AdminRole => 'PORTAL_PROFILES_READ' },
        create => { AdminRole => 'PORTAL_PROFILES_CREATE' },
        update => { AdminRole => 'PORTAL_PROFILES_UPDATE' },
    },
);


=head2 Methods

=over

=item index

=cut

sub index :Path :Args(0) {
    my ($self, $c) = @_;
    $c->forward('object');
}


=item isDeleteOrRevertDisabled

=cut

sub isDeleteOrRevertDisabled {return 1};

=item object

The default chained dispatcher

/config/profile/default

=cut

sub object :Chained('/') :PathPart('config/profile/default') :CaptureArgs(0) {
    my ($self, $c) = @_;
    return $self->SUPER::object($c,'default');
}

=item _make_file_path

=cut

sub _makeFilePath {
    my ($self,@args) = @_;
    return $self->_makeDefaultFilePath(@args);
}

=item delete_file

=cut

sub delete_file :Chained('object') :PathPart('delete') :Args() :AdminRole('PORTAL_PROFILES_UPDATE') {
    my ($self,$c,@pathparts) = @_;
    $c->stash->{status_msg} = "Cannot delete a file in the default profile";
    $c->go('bad_request');
}

=item revert_file

=cut

sub revert_file :Chained('object') :PathPart :Args() :AdminRole('PORTAL_PROFILES_UPDATE') {
    my ($self,$c,@pathparts) = @_;
    $c->stash->{status_msg} = "Cannot revert a file in the default profile";
    $c->go('bad_request');
}

=item revert_all

=cut

sub revert_all :Chained('object') :PathPart :Args(0) :AdminRole('PORTAL_PROFILES_UPDATE') {
    my ($self,$c) = @_;
    $c->stash->{status_msg} = "Cannot revert files in the default profile";
    $c->go('bad_request');
}

=item remove

=cut

sub remove :Chained('object') :PathPart :Args(0) {
    my ($self,$c) = @_;
    $c->stash->{status_msg} = "Cannot delete the default profile";
    $c->go('bad_request');
}

=item end

=cut

sub end: Private {
    my ($self,$c) = @_;
    if(! exists($c->stash->{template})) {
        $c->stash(
            template => 'config/profile/' . $c->action->name . '.tt'
        );
    }
    $c->forward('Controller::Root','end');
}

=back

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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

