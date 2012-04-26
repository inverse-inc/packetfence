package configurator::Model::Interface;
use Moose;
use namespace::autoclean;

extends 'Catalyst::Model';

=head1 NAME

configurator::Model::Interface - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
