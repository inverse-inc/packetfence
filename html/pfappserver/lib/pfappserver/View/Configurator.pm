package pfappserver::View::Configurator;

use strict;
use warnings;

use Moose;
extends 'pfappserver::View::HTML';

__PACKAGE__->config(
    WRAPPER => 'configurator/wrapper.tt',
);

=head1 NAME

pfappserver::View::Configurator - HTML View for configurator

=head1 DESCRIPTION

TT View for configurator.

=head1 SEE ALSO

L<pfappserver>

=head1 AUTHOR

Francis Lachapelle <flachapelle@inverse.ca>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
