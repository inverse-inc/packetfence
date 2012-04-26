package configurator::View::HTML;

use strict;
use warnings;

use base 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    render_die => 1,
);

=head1 NAME

configurator::View::HTML - TT View for configurator

=head1 DESCRIPTION

TT View for configurator.

=head1 SEE ALSO

L<configurator>

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
