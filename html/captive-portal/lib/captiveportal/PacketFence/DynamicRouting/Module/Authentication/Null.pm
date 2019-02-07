package captiveportal::PacketFence::DynamicRouting::Module::Authentication::Null;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::Null

=head1 DESCRIPTION

Null auth module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Authentication';
with 'captiveportal::Role::FieldValidation';

use pf::util;
use pf::config qw($default_pid);
use pf::log;
use pf::auth_log;
use pf::Authentication::constants;
use pf::constants::realm;

has '+source' => (isa => 'pf::Authentication::Source::NullSource');

has 'pid_field' => (is => 'rw', builder => '_build_pid_field', lazy => 1);

=head2 _build_pid_field

Email is only required if the source says so

=cut

sub _build_pid_field {
    my ($self) = @_;
    return $self->requires_email ? "email" : undef;
}

=head2 execute_child

Execute this module

=cut

sub execute_child {
    my ($self) = @_;
    if($self->app->request->method eq "POST"){
        $self->authenticate();
    }
    else {
        $self->prompt_fields();
    }
}

=head2 authenticate

Validate the submitted informations

=cut

sub authenticate {
    my ($self) = @_;
    my $pid;

    if($self->requires_email) {
        $pid = $self->request_fields->{$self->pid_field};

        get_logger->info("Validating e-mail for user $pid");
        my ($return, $message, $source_id, $extra) = pf::authentication::authenticate({username => $pid, password => '', rule_class => $Rules::AUTH, context => $pf::constants::realm::PORTAL_CONTEXT}, $self->source);
        if(defined($return) && $return == 1){
            pf::auth_log::record_auth($source_id, $self->current_mac, $pid, $pf::auth_log::COMPLETED, $self->app->profile->name);
        }
        else {
            pf::auth_log::record_auth($self->source, $self->current_mac, $pid, $pf::auth_log::FAILED, $self->app->profile->name);
            $self->app->flash->{error} = $message;
            $self->prompt_fields();
            return;
        }
        $self->update_person_from_fields();
    }
    else {
        $pid = $default_pid;
        pf::auth_log::record_auth($self->source->id, $self->current_mac, $pid, $pf::auth_log::COMPLETED, $self->app->profile->name);
    }
    $self->username($pid);
    $self->done();
}

=head2 requires_email

Whether or not the email is required

=cut

sub requires_email {
    my ($self) = @_;
    return isenabled($self->source->{email_required});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

