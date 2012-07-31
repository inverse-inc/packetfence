package pfappserver::View::HTML;

use strict;
use warnings;

use base 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    PRE_PROCESS => 'macros.inc',
    FILTERS => {
        id => \&id_filter,
    },
    render_die => 1,
);

=head1 NAME

pfappserver::View::HTML - TT View for pfappserver

=head1 DESCRIPTION

TT View for pfappserver.

=head1 SEE ALSO

L<pfappserver>

=cut

sub id_filter {
    my $id = shift;
    $id =~ s/\./_/g;

    return $id;
}

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
