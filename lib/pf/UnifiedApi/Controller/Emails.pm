package pf::UnifiedApi::Controller::Emails;

=head1 NAME

pf::UnifiedApi::Controller::Emails -

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Emails

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use Data::Dumper;
use MIME::Base64;
use pf::config::util qw();

sub handle_email_payload {
    my ($self) = @_;
    my $data = $self->parse_json;
    $data->{subject} //= "Preview";
    $data->{args} //= {};

    unless($data->{template}) {
        $self->render_error(422, "Missing 'template' parameter");
        return undef;
    }

    return $data;
}

sub preview {
    my ($self) = @_;

    my $data = $self->handle_email_payload();

    return unless($data);

    my $msg = pf::config::util::build_email($data->{template}, 'dummy@example.com', $data->{subject}, $data->{args});
    return $self->render(json => {body => MIME::Base64::decode($msg->body_as_string)});
}

sub send_email {
    my ($self) = @_;

    my $data = $self->handle_email_payload();

    return unless($data);

    unless($data->{to}) {
        return $self->render_error(422, "Missing 'to' parameter");
    }

    my $msg = pf::config::util::build_email($data->{template}, $data->{to}, $data->{subject}, $data->{args});
    my $success = pf::config::util::send_using_smtp_callback($msg);
    my $user_message = $success ? "Successfully sent email to $data->{to}" : "Failed to send email to $data->{to}. Check server side logs for details";
    return $self->render(json => {message => $user_message}, status => ($success ? 200 : 500));
}

sub pfmailer {
    my ($self) = @_;
    my ($status, $data) = $self->parse_json;
    if (is_error($status)) {
        return $self->render(json => $data, status => $status);
    }

    my @errors;
    unless ($data->{subject}) {
        push @errors, {message => "Required field missing", field => 'subject' };
    }
    unless ($data->{message}) {
        push @errors, {message => "Required field missing", field => 'message' };
    }

    if (@errors) {
        return $self->render_error(422, "Missing required fields", \@errors);
    }

    pf::config::util::pfmailer(%$data);
    return $self->render(status => 200, json => {});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
