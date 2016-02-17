package captiveportal::DynamicRouting::I18N;

use Moose;
extends 'HTML::FormHandler::I18N';

use Locale::gettext qw(gettext ngettext);

sub maketext {
    my $self = shift;
    my @args = @_;
    $args[0] =~ s/\[\_.+?\]/\%s/g;
    if(@args > 1){
        return $self->i18n_format(@args);
    }
    else {
        return $self->i18n(@args);
    }
}

sub i18n {
    my ( $self, $msgid ) = @_;

    my $msg = gettext($msgid);
    utf8::decode($msg);

    return $msg;
}

sub ni18n {
    my ( $self, $singular, $plural, $category ) = @_;

    my $msg = ngettext( $singular, $plural, $category );
    utf8::decode($msg);

    return $msg;
}

=head2 i18n_format

Pass message id through gettext then sprintf it.

Meant to be called from the TT templates.

=cut

sub i18n_format {
    my ( $self, $msgid, @args ) = @_;
    my $msg = sprintf( gettext($msgid), @args );
    utf8::decode($msg);
    return $msg;
}


1;
