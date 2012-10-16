package pfappserver::Form::Widget::Theme::Pf;
use Moose::Role;
with 'HTML::FormHandler::Widget::Theme::Bootstrap';

sub build_update_subfields {{
    by_type =>
      {
       'Date' =>
       {
        element_class => ['datepicker', 'input-small'],
        element_attr => {'data-date-format' => 'yyyy-mm-dd',
                         placeholder => 'yyyy-mm-dd'},
       },
       'IntRange' =>
       {
        element_class => ['span2'],
       },
       'PosInteger' =>
       {
        element_class => ['span2'],
        element_attr => {'min' => '0'},
       },
       '+Duration' =>
       {
        wrapper_class => ['interval'],
       },
       'Uneditable' =>
       {
        element_class => ['uneditable'],
       },
      },
}}

sub update_fields {
    my $self = shift;

    foreach my $field (@{$self->fields}) {
        if ($field->required) {
            $field->element_attr({'data-required' => 'required'});
        }
        if ($field->type eq 'PosInteger') {
            $field->element_attr({'data-type' => 'number'});
            $field->type_attr($field->html5_type_attr);
        }
    }
}

1;
