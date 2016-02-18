package captiveportal::PacketFence::View::HTML;

use strict;
use warnings;
use Locale::gettext qw(gettext ngettext);
use Moose;
use utf8;
extends 'Catalyst::View';

#__PACKAGE__->config(
#    TEMPLATE_EXTENSION => '.html',
#    ENCODING           => 'utf-8',
#    render_die         => 1,
#    expose_methods     => [qw(i18n ni18n i18n_format)],
#);
#
#before process => sub {
#    my ( $self, $c ) = @_;
#    my $include_path = $c->portalSession->templateIncludePath;
#    @{ $self->include_path } = @$include_path;
#};

sub process {
    my ($self, $c) = @_;
    $c->stash->{application}->render($c->stash->{template}, $c->stash);
    $c->response->body($c->stash->{application}->template_output);
}

sub i18n {
    my ( $self, $c, $msgid ) = @_;

    my $msg = gettext($msgid);
    utf8::decode($msg);

    return $msg;
}

sub ni18n {
    my ( $self, $c, $singular, $plural, $category ) = @_;

    my $msg = ngettext( $singular, $plural, $category );
    utf8::decode($msg);

    return $msg;
}

=head2 i18n_format

Pass message id through gettext then sprintf it.

Meant to be called from the TT templates.

=cut

sub i18n_format {
    my ( $self, $c, $msgid, @args ) = @_;
    my $msg = sprintf( gettext($msgid), @args );
    utf8::decode($msg);
    return $msg;
}

=head1 NAME

captiveportal::View::HTML - TT View for captiveportal

=head1 DESCRIPTION

TT View for captiveportal.

=head1 SEE ALSO

L<captiveportal>

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

1;
