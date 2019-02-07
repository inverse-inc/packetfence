package pfappserver::Form::Widget::Field::ButtonGroup;

=head1 NAME

pfappserver::Form::Widget::Field::ButtonGroup - radio buttons bootstrap-style

=head1 DESCRIPTION

This field extends the default RadioGroup and renders it as a series of links
as possible in Bootstrap.

=cut

use Moose::Role;
use HTML::FormHandler::Render::Util ('process_attrs');
with 'HTML::FormHandler::Widget::Field::RadioGroup';
with 'HTML::FormHandler::Widget::Field::Hidden' => {
    -excludes => 'render_element',
    -alias => {
        'render_element' => 'render_element_hidden'
    }
};

use namespace::autoclean;

sub render_element {
    my ( $self, $result ) = @_;
    $result ||= $self->result;

    my $output = "";
    my $hidden = 0;

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
        unless ($hidden) {
            $output .= $self->render_element_hidden();
            $hidden = 1;
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
    $output .= ' disabled'
        if $self->element_attr->{'disabled'};
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

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;
