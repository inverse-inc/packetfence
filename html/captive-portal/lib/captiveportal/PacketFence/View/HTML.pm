package captiveportal::PacketFence::View::HTML;

use strict;
use warnings;
use Locale::gettext qw(gettext ngettext);
use Moose;
extends 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.html',
    render_die         => 1,
    expose_methods     => [qw(i18n ni18n i18n_format)],
);

before process => sub {
    my ( $self, $c ) = @_;
    my $include_path = $c->portalSession->templateIncludePath;
    @{ $self->include_path } = @$include_path;
};

sub i18n {
    my ( $self, $c, $msgid ) = @_;
    return gettext($msgid);
}

sub ni18n {
    my ( $self, $c, $singular, $plural, $category ) = @_;

    return ngettext( $singular, $plural, $category );
}

=head2 i18n_format

Pass message id through gettext then sprintf it.

Meant to be called from the TT templates.

=cut

sub i18n_format {
    my ( $self, $c, $msgid, @args ) = @_;
    return sprintf( gettext($msgid), @args );
}

=head1 NAME

captiveportal::View::HTML - TT View for captiveportal

=head1 DESCRIPTION

TT View for captiveportal.

=head1 SEE ALSO

L<captiveportal>

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
