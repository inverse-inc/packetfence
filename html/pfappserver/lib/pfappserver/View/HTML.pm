package pfappserver::View::HTML;

use strict;
use warnings;

use base 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    PRE_PROCESS => 'macros.inc',
    FILTERS => {
        css => \&css_filter,
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

=head2 css_filter

=cut
sub css_filter {
    my $string = shift;
    $string =~ s/[^_a-zA-Z0-9]/_/g;

    return $string;
}

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
