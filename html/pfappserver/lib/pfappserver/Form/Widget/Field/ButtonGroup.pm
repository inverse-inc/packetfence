package pfappserver::Form::Widget::Field::ButtonGroup;
# ABSTRACT: radio group rendering widget
use Moose::Role;
#use namespace::autoclean;
use HTML::FormHandler::Render::Util ('process_attrs');
with 'HTML::FormHandler::Widget::Field::RadioGroup';

sub render_element {
    my ( $self, $result ) = @_; 
    $result ||= $self->result;

    my $output = '<input type="hidden" name="'
      . $self->html_name . '" value="';
    $output .= $self->value if ($self->value);
    $output .= '">';

    foreach my $option ( @{ $self->{options} } ) { 
        if ( my $label = $option->{group} ) { 
            $label = $self->_localize( $label ) if $self->localize_labels;
            my $attr = $option->{attributes} || {}; 
            my $attr_str = process_attrs($attr);
            my $lattr = $option->{label_attributes} || {}; 
            my $lattr_str= process_attrs($attr);
            $output .= qq{\n<div$attr_str><label$lattr_str>$label</label>};
            foreach my $group_opt ( @{ $option->{options} } ) { 
                $output .= $self->render_option( $group_opt, $result );
            }   
            $output .= qq{\n</div>};
        }   
        else {
            $output .= $self->render_option( $option, $result );
        }   
    }   
    $self->reset_options_index;
    return $output;
}

sub render_radio {
    my ( $self, $result, $option ) = @_;
    $result ||= $self->result;

    my $value = $option->{value};
    my $id = $self->id . "." . $self->options_index;
    my $output = '  <a name="'
        . $self->html_name . '" class="btn';
    $output .= ' active'
        if $result->fif eq $value;
    $output .= '" value="'
        . $self->html_filter($value) . '"';
    $output .= process_attrs($option->{attributes});
    $output .= '>';
    return $output;
}  

sub wrap_radio {
    my ( $self, $rendered_widget, $option_label ) = @_; 

    my $label = $self->_localize($option_label);
    return qq{$rendered_widget$label</a>\n};
}

1;
