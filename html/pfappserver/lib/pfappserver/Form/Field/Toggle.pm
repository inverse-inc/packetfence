package pfappserver::Form::Field::Toggle;

use Moose;
extends 'HTML::FormHandler::Field::Checkbox';
use namespace::autoclean;

=head1 DESCRIPTION

This field returns Y if true, N if false.

=cut

has '+checkbox_value' => ( default => 'Y' );
has '+inflate_default_method'=> ( default => sub { \&toggle_inflate } );

sub toggle_inflate {
    my ($self, $value) = @_;

    return 'N' unless ($value =~ m/^(y|yes|true|enabled|1)$/i);
    return 'Y';
}

__PACKAGE__->meta->make_immutable;
1;
