package captiveportal::PacketFence::DynamicRouting::Module::Authentication::SponsorDefined;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::SponsorDefined

=head1 DESCRIPTION

Sponsoring module

=cut

use Moose;
use pf::Authentication::constants;
use pf::config qw(%Config);
use pf::log;
use Date::Format qw(time2str);
use pf::activation;
use pf::web::guest;
use pf::util qw(normalize_time);

extends 'captiveportal::DynamicRouting::Module::Authentication::Sponsor';

has '+source' => (isa => 'pf::Authentication::Source::SponsorEmailSource');
has 'sponsor' => (is => 'rw');



=head2 _build_required_fields

Build the required fields based on the PID field, the custom fields and the mandatory fields of the source

=cut

sub _build_required_fields {
    my ($self) = @_;
    my @fields = ((grep {$_ ne 'sponsor'} @{$self->SUPER::_build_required_fields()}));

    return \@fields;
}

sub do_sponsor_registration {
    my ($self) = @_;
    my %info;
    get_logger->info("registering  guest through a sponsor");

    my $source = $self->source;
    my $pid = $self->request_fields->{$self->pid_field};
    my $email = $self->request_fields->{email};
    $info{'pid'} = $pid;

    my ( $status, $status_msg ) = $source->authenticate($pid);
    unless ( $status ) {
        $self->app->flash->{error} = $status_msg;
        $self->prompt_fields();
        return;
    }

    return unless($self->_validate_sponsor($self->sponsor));

    # form valid, adding person (using modify in case person already exists)
    my $note = 'sponsored confirmation Date of arrival: ' . time2str("%Y-%m-%d %H:%M:%S", time);

    get_logger->info( "Adding guest person " . $pid );

    $info{'cc'} = $source->{sponsorship_cc};
    $info{'activation_domain'} = $source->{activation_domain} if (defined($source->{activation_domain}));
    $info{'activation_timeout'} = normalize_time($source->{email_activation_timeout});
    # fetch more info for the activation email
    # this is meant to be overridden in pf::web::custom with customer specific needs
    foreach my $key (qw(firstname lastname telephone company)) {
        $info{$key} = $self->request_fields->{$key};
    }
    $info{'sponsor'} = $self->sponsor;
    $info{'subject'} = $self->app->i18n_format("%s: Guest access request", $Config{'general'}{'domain'});

    # TODO this portion of the code should be throttled to prevent malicious intents (spamming)
    my ( $auth_return, $err, $activation_code ) =
      pf::activation::create_and_send_activation_code(
        $self->current_mac,
        $pid,
        $info{'sponsor'},
        $pf::web::guest::TEMPLATE_EMAIL_SPONSOR_ACTIVATION,
        $pf::activation::SPONSOR_ACTIVATION,
        $self->app->profile->getName,
        %info,
      );

    pf::auth_log::record_guest_attempt($source->id, $self->current_mac, $pid);

    $self->session->{activation_code} = $activation_code;
    $self->app->session->{email} = $email;
    $self->username($email);

    $self->update_person_from_fields();

    $self->waiting_room();
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

