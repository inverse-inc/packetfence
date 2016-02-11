package captiveportal::DynamicRouting::AuthModule::Null;

=head1 NAME

captiveportal::DynamicRouting::AuthModule::Null

=head1 DESCRIPTION

Null auth module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::AuthModule';
with 'captiveportal::DynamicRouting::FieldValidation';

use pf::util;
use pf::config;
use pf::log;

has '+source' => (isa => 'pf::Authentication::Source::NullSource');

has 'pid_field' => (is => 'rw', builder => '_build_pid_field', lazy => 1);

sub _build_pid_field {
    my ($self) = @_;
    return $self->requires_email ? "email" : undef;
}

sub execute_child {
    my ($self) = @_;    
    if($self->app->request->method eq "POST"){
        $self->authenticate();
    }
    else {
        $self->prompt_fields();
    }
}

sub authenticate {
    my ($self) = @_;
    my $pid;

    if($self->requires_email) {
        $pid = $self->request_fields->{$self->pid_field};
        
        get_logger->info("Validating e-mail for user $pid");
        my ($return, $message, $source_id) = pf::authentication::authenticate({username => $pid, password => '', rule_class => $Rules::AUTH}, $self->source); 
        if(defined($return) && $return == 1){
            pf::auth_log::record_auth($source_id, $self->current_mac, $pid, $pf::auth_log::COMPLETED);
        }
        else {
            pf::auth_log::record_auth($self->source, $self->current_mac, $pid, $pf::auth_log::FAILED);
            $self->app->flash->{error} = $self->app->i18n($message);
            $self->prompt_fields();
            return;
        }
    }
    else {
        $pid = $default_pid;
    }
    $self->update_person_from_fields();
    $self->username($pid);
    $self->done();
}

sub requires_email {
    my ($self) = @_;
    return isenabled($self->source->{email_required});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

__PACKAGE__->meta->make_immutable;

1;

