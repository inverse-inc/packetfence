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
use Encode qw();
use pf::error qw(is_error);
use pf::config::util qw();
use pf::web::constants;

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

    my $msg = pf::config::util::build_email($data->{template}, 'dummy@example.com', $data->{subject}, $data->{args}, $self->email_template_options($data));
    return $self->render(json => {body => Encode::decode_utf8(MIME::Base64::decode($msg->body_as_string))});
}

sub send_email {
    my ($self) = @_;

    my $data = $self->handle_email_payload();

    return unless($data);

    unless($data->{to}) {
        return $self->render_error(422, "Missing 'to' parameter");
    }

    my $msg = pf::config::util::build_email($data->{template}, $data->{to}, $data->{subject}, $data->{args}, $self->email_template_options($data));
    my $success = pf::config::util::send_using_smtp_callback($msg);
    my $user_message = $success ? "Successfully sent email to $data->{to}" : "Failed to send email to $data->{to}. Check server side logs for details";
    return $self->render(json => {message => $user_message}, status => ($success ? 200 : 500));
}

=head2 email_template_options

The template options of build_email for the language of the request: the
'locale' of the payload if given, otherwise the Accept-Language header (the
admin UI sends its language). Without a supported language, the default
language is used.

=cut

sub email_template_options {
    my ($self, $data) = @_;
    my @languages = grep { $_ ne 'i-default' } @{ $self->stash->{languages} // [] };
    unshift @languages, $data->{locale} if defined $data->{locale} && $data->{locale} ne '';
    my $locale = email_locale(@languages);
    return defined $locale ? { __locale => $locale } : {};
}

=head2 email_locale

The first of the languages (fr, fr-CA, pt_BR) that matches a supported locale
of @WEB::LOCALES: the same locale, or the first one of the same language.
Returns undef when none matches, so the default language is used.

=cut

sub email_locale {
    my (@languages) = @_;
    for my $lang (@languages) {
        next unless defined $lang && $lang =~ /^([a-zA-Z]{2,3})(?:[-_]([a-zA-Z]{2}))?$/;
        my ($language, $region) = (lc($1), $2);
        if (defined $region) {
            my $exact = "${language}_\U$region";
            return $exact if grep { $_ eq $exact } @WEB::LOCALES;
        }
        my ($same_language) = grep { /^${language}_/ } @WEB::LOCALES;
        return $same_language if defined $same_language;
    }
    return undef;
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

    pf::config::util::pfmailer_now(%$data);
    return $self->render(status => 200, json => {});
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
