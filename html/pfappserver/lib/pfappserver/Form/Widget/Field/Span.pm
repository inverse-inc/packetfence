package pfappserver::Form::Widget::Field::Span;

=head1 SYNOPSIS

Renders the NonEditable pseudo-field as a span.

   <span id="my_field" class="test">The Field Value</span>

=cut

use Moose::Role;
use HTML::FormHandler::Render::Util ('process_attrs');
with 'HTML::FormHandler::Widget::Field::Span';
use namespace::autoclean;

sub render_element {
    my ( $self, $result ) = @_;
    $result ||= $self->result;

    my $output = '<span';
    $output .= ' id="' . $self->id . '"';
    $output .= process_attrs($self->element_attributes($result));
    $output .= '>'; # the shipped version is incorrectly closing the span tag
    $output .= $self->value;
    $output .= '</span>';
    return $output;
}

1;
