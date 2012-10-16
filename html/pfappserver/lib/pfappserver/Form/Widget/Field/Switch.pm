package pfappserver::Form::Widget::Field::Switch;
# ABSTRACT: radio group rendering widget
use Moose::Role;
use namespace::autoclean;
use HTML::FormHandler::Render::Util ('process_attrs');

#        <div class="control-group">
#          <label class="control-label" for="enabled">Enabled</label>
#          <div class="controls">
#            <div class="onoffswitch">
#              <input type="checkbox" name="enabled" class="onoffswitch-checkbox" id="enabled">
#                <label class="onoffswitch-label" for="enabled">
#                  <div class="onoffswitch-inner">
#                    <div class="onoffswitch-active">ON</div>
#                    <div class="onoffswitch-inactive">OFF</div>
#                  </div>
#                  <div class="onoffswitch-switch"></div>
#                </label>
#            </div>
#          </div>
#        </div>

sub render_element {
    my ( $self, $result ) = @_; 
    $result ||= $self->result;

    my $checkbox_value = $self->checkbox_value;
    my $output = qq[<div class="onoffswitch">\n]
        . '<input type="checkbox" class="onoffswitch-checkbox" name="'
        . $self->html_name . '" id="' . $self->id . '" value="'
        . $self->html_filter($checkbox_value) . '"';
    $output .= ' checked="checked"'
        if $result->fif eq $checkbox_value;
    $output .= process_attrs($self->element_attributes($result));
    $output .= ' />';
    $output .=  qq[  
  <label class="onoffswitch-label" for="enabled">
    <div class="onoffswitch-inner">
      <div class="onoffswitch-active">ON</div>
      <div class="onoffswitch-inactive">OFF</div>
    </div>
    <div class="onoffswitch-switch"></div>
  </label>
</div>
];

    return $output;
}

sub render {
    my ( $self, $result ) = @_; 
    $result ||= $self->result;
    die "No result for form field '" . $self->full_name . "'. Field may be inactive." unless $result;
    my $output = $self->render_element( $result );
    return $self->wrap_field( $result, $output );
}

1;
