package captiveportal::DynamicRouting::AuthModule::Email;

=head1 NAME

captiveportal::DynamicRouting::AuthModule::Email

=head1 DESCRIPTION

Login registration

=cut

use Moose;
extends 'captiveportal::DynamicRouting::AuthModule';
with 'captiveportal::DynamicRouting::FieldValidation';

use pf::auth_log;
use pf::config;
use pf::log;
use pf::authentication;
use pf::Authentication::constants;
use Date::Format qw(time2str);
use pf::util;

sub required_fields_child {
    return ["email"];
}

sub execute_child {
    my ($self) = @_;
    if($self->app->request->method eq "POST"){
        $self->do_email_registration();
    }
    else{
        $self->prompt_fields();
    }
};

sub do_email_registration {
    my ($self) = @_;
    my $logger = get_logger;

    # fetch role for this user
    my $source = $self->source;
    my $pid = $self->request_fields->{$self->pid_field};
    my $email = $self->request_fields->{email};

    my %info;
    $info{'activation_domain'} = $source->{activation_domain} if (defined($source->{activation_domain}));

    # form valid, adding person (using modify in case person already exists)
    my $note = 'email activation. Date of arrival: ' . time2str("%Y-%m-%d %H:%M:%S", time);
    $self->update_person_from_fields(notes => $note);

    $info{'firstname'} = $self->request_fields->{firstname};
    $info{'lastname'} = $self->request_fields->{lastname};
    $info{'telephone'} = $self->request_fields->{telephone};
    $info{'company'} = $self->request_fields->{company};
    $info{'subject'} = $self->app->i18n_format("%s: Email activation required", $Config{'general'}{'domain'});
    utf8::decode($info{'subject'});

    # TODO this portion of the code should be throttled to prevent malicious intents (spamming)
    my ( $auth_return, $err, $errargs_ref ) =
      pf::activation::create_and_send_activation_code(
        $self->current_mac,
        $pid, $email,
        $pf::web::guest::TEMPLATE_EMAIL_GUEST_ACTIVATION,
        $pf::activation::GUEST_ACTIVATION,
        $self->app->profile->getName,
        %info,
      );
    
    pf::auth_log::record_guest_attempt($source->id, $self->current_mac, $pid);


    $self->new_node_info->{unregdate} = $info{unregdate};

    $self->session->{fields} = $self->request_fields;
    $self->app->session->{email} = $email;
    $self->username($pid);

    $self->done();

}

# overriding here since we don't want the unregdate to be updated as they will be at the end of the process
after 'execute_actions' => sub {
    my ($self) = @_;

    get_logger->debug("Source ".$self->source->id." has an activation timeout of ".$self->source->{email_activation_timeout});
    # Use the activation timeout to set the unregistration date
    my $timeout = normalize_time( $self->source->{email_activation_timeout} );
    my $unregdate = POSIX::strftime( "%Y-%m-%d %H:%M:%S",localtime( time + $timeout ) );
    get_logger->debug( "Registration for guest ".$self->app->session->{username}." is valid until $unregdate (delay of $timeout s)" );

    $self->new_node_info->{unregdate} = $unregdate;
};

sub auth_source_params {
    my ($self) = @_;
    return {
        user_email => $self->app->session->{email},
    };
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

