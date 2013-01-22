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

=head2 index

=cut
sub index : Local: Path : Private {}

=head2 object

The default chained dispatcher

/portal/profile/default

=cut

our %PF_CONFIG_NAME_MAP = (
    'general.logo'                          => 'logo',
    'registration.guests_self_registration' => 'guest_self_reg',
    'guests_self_registration.modes'        => 'guest_modes',
    'registration.billing_engine'           => 'billing_engine',

    'logo'           => 'general.logo',
    'guest_self_reg' => 'registration.guests_self_registration',
    'guest_modes'    => 'guests_self_registration.modes',
    'billing_engine' => 'registration.billing_engine',
);

our @PF_CONFIG_ENTRIES = qw(
    general.logo
    registration.guests_self_registration
    guests_self_registration.modes
    registration.billing_engine
);

our @PROFILE_ENTRIES = @PF_CONFIG_NAME_MAP{@PF_CONFIG_ENTRIES};

sub is_delete_or_revert_disabled {return 1};
sub object :Chained('/') :PathPart('portal/profile/default') :CaptureArgs(0) {
    my ($self, $c) = @_;
    my $pf_config = $c->model('Config::Pf');
    my ($status,$config_ref) = $pf_config->read_value(\@PF_CONFIG_ENTRIES);
    $c->stash->{profile_name} = 'default';
    my %profile;
    @profile{'id','description',@PF_CONFIG_NAME_MAP{@PF_CONFIG_ENTRIES}} = (
        'default',
        'The Default Profile',
        @{$config_ref}{@PF_CONFIG_ENTRIES}
    );
    $c->stash->{profile} = \%profile;
}

sub _get_form {
    my ($self,$c,@args) = @_;
    return pfappserver::Form::Portal::Profile::Default->new(ctx => $c,@args);
}

sub _update_profile {
    my ($self,$c,$form) = @_;
    my $pf_config = $c->model('Config::Pf');
    my $profile = $form->value;
    my %new_profile;
    @new_profile{@PF_CONFIG_NAME_MAP{@PROFILE_ENTRIES}} = @{$profile}{@PROFILE_ENTRIES};
    use Data::Dumper;
    $c->log->info(Dumper(\%new_profile));
    return $pf_config->update(\%new_profile);
}

sub _make_file_path {
    my ($self,@args) = @_;
    return $self->_make_default_file_path(@args);
}

sub delete_file :Chained('object') :PathPart('delete') :Args() {
    my ($self,$c,@pathparts) = @_;
    $c->stash->{status_msg} = "Cannot delete a file in the default profile";
    $c->go('bad_request');
}

sub revert_file :Chained('object') :PathPart :Args() {
    my ($self,$c,@pathparts) = @_;
    $c->stash->{status_msg} = "Cannot revert a file in the default profile";
    $c->go('bad_request');
}

sub filter_entries {
    my ($regex,@entries);
}

sub revert_all :Chained('object') :PathPart :Args(0) {
    my ($self,$c) = @_;
    $c->stash->{status_msg} = "Cannot revert files in the default profile";
    $c->go('bad_request');
}

sub delete_profile :Chained('object') :PathPart('delete') :Args(0) {
    my ($self,$c) = @_;
    $c->stash->{status_msg} = "Cannot delete the default profile";
    $c->go('bad_request');
}

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

