package configurator::View::Configurator;

use strict;
use warnings;

use Moose;
extends 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    WRAPPER => 'wizard/wrapper.tt',
    PRE_PROCESS => 'macros.inc',
    render_die => 1,
);

=head1 NAME

configurator::View::Configurator - TT View for configurator

=head1 DESCRIPTION

TT View for configurator.

=head1 SEE ALSO

L<configurator>

=head1 AUTHOR

Francis Lachapelle <flachapelle@inverse.ca>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
