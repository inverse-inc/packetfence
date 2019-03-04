package pfappserver::Form::Field::DynamicList;

=head1 NAME

pfappserver::Form::Field::DynamicList - Provides a dynamic list field

=cut

=head1 DESCRIPTION

pfappserver::Form::Field::DynamicList

=cut

use strict;
use warnings;
use Moose;
extends 'HTML::FormHandler::Field::Repeatable';
use pf::log;


has '+do_wrapper' => ( default => 1 );
has '+widget_tags' => ( default => \&build_widget_tags );
has '+init_contains' => ( default => \&build_init_contains );
has 'sortable' => ( is =>'rw', default => 0 );

sub BUILD {
    my ($self, @args) = @_;
    $self->add_wrapper_class(qw(dynamic-list-sortable)) if $self->sortable;
}

=head2 before wrapper_attr

Set the wrapper to a hidden field if there are no fields

=cut

before 'wrapper_attr' => sub {
    my ($self, @args) = @_;
    if ($self->num_fields == 0) {
        $self->add_wrapper_class("hidden");
    }
};

=head2 set_disabled

set a field and all it's sub fields to disabled

=cut

sub set_disabled {
    my ($field) = @_;
    get_logger->trace(sub { "Setting " . $field->id . " to disabled" });
    if ($field->can("fields")) {
        foreach my $subfield ($field->fields) {
            set_disabled($subfield);
        }
    }
    $field->disabled(1);
}

=head2 build_widget_tags

Provide the default tags for the widget

=cut

sub build_widget_tags {
    return {
        after_wrapper => \&append_add_button
    };
}

=head2 child_options

A helper function to populate child options for contains

=cut

sub child_options {
    return (
        do_wrapper  => 1,
        tags =>
        {
            input_append => \&append_delete_button,
            input_prepend => \&prepend_sort_handle,
        }
    );
}

=head2 build_init_contains

Initialize the contains sub field

=cut

sub build_init_contains {
    {
        child_options()
    }
}


=head2 prepend_sort_handle

Create a sort handle for a sortable DynamicList

=cut

sub prepend_sort_handle {
    my ($field) = @_;
    my $parent = $field->parent;
    return "" unless $parent->sortable;
    my $target_id = $parent->target_id;
    my $base_id = $parent->id;
    my $scope = "sortable-" . $base_id;
    my $name = $field->name + 1;
    my $label = $field->label;
    my $target = escape_jquery_id($field->id);
    my $content = qq{<span data-sortable-text="$label" data-base-id="$base_id" data-sortable-item="#$target" data-sortable-scope="$scope" data-sortable-parent="$target_id" class="sort-handle">$name</span>};
    return $content;
}

=head2 append_add_button

Append the add button for the DynamicList

=cut

sub append_add_button {
    my ($self) = @_;
    my $cg_hidden = "";
    if ($self->num_fields) {
        $cg_hidden = "hidden";
    }
    my $extra_field = $self->_add_extra(999);
    set_disabled($extra_field);
    my $id = $self->id;
    my $button_text = "Add " . $extra_field->label;
    my $content = $extra_field->render;
    # remove extra result & field, now that it's rendered
    my $template_id = $self->template_id;
    my $target_wrapper = $self->target_wrapper;
    my $template_target = $self->template_target;
    my $target = $self->target_id;
    my $control_group_id = $self->template_control_group_id;
    my $append_controls = $self->do_append_controls($button_text);
    $self->result->_pop_result;
    $self->_pop_field;
    my $label =  $self->do_label ? $self->do_render_label(undef, undef,  ['control-label']) : '';
    return <<"EOS";
    <div class="control-group $cg_hidden" id="$control_group_id" >
        $label
        <div id="$template_id" class="hidden">$content</div>
        <div class="controls">$append_controls</div>
    </div>
EOS
}

=head2 template_control_group_id

Returns the id of the template control group

=cut

sub template_control_group_id {
    my ($self) = @_;
    my $template_id = $self->template_id;
    return "${template_id}_control_group";
}

=head2 template_control_group_target

Returns the target for the template control group

=cut

sub template_control_group_target {
    my ($self) = @_;
    return '#' . escape_jquery_id($self->template_control_group_id);
}

=head2 do_append_controls

Returns the additional controls or the tag dynamic-list-append_controls

=cut

sub do_append_controls {
    my ($self, $button_text) = @_;
    my $content  = $self->get_tag("dynamic-list-append_controls");
    return $content if $content;
    my $attrs = $self->add_button_attr;
    return qq{<a$attrs class="btn">$button_text</a>};
}

=head2 delete_button_attr

Returns the attributes of delete button

=cut

sub delete_button_attr {
    my ($self, $field) = @_;
    my $target = escape_jquery_id($field->id);
    my $base_id = $self->id;
    my $target_wrapper = $self->target_wrapper;
    my $template_target = $self->template_target;
    my $template_control_group_target = $self->template_control_group_target;
    my $attr = qq{ data-toggle="dynamic-list-delete" data-template-control-group="${template_control_group_target}" data-target-wrapper="${target_wrapper}" data-base-id="$base_id" data-target="#$target" };
    return $attr;
}

=head2 add_button_attr

Returns the attributes of add button

=cut

sub add_button_attr {
    my ($self) = @_;
    my $id = $self->id;
    my $template_id = $self->template_id;
    my $target_wrapper = $self->target_wrapper;
    my $template_target = $self->template_target;
    my $target = $self->target_id;
    my $template_control_group_target = $self->template_control_group_target;
    return qq{ data-toggle="dynamic-list" data-template-control-group="${template_control_group_target}" data-target="${target}" data-target-wrapper="${target_wrapper}" data-template-parent="#$template_target" data-base-id="$id" };
}

=head2 target_wrapper

Returns the target of the wrapper

=cut

sub target_wrapper {
    my ($self) = @_;
    return '#' . escape_jquery_id($self->id);
}

=head2 append_delete_button

Returns the delete button to be appended

=cut

sub append_delete_button {
    my ($field) = @_;
    my $target = escape_jquery_id($field->id);
    my $parent = $field->parent;
    my $add_attrs = $parent->add_button_attr;
    my $delete_attrs = $parent->delete_button_attr($field);
    return qq{
        <a class="btn-icon" $add_attrs><i class="icon-plus-circle"></i></a>
        <a class="btn-icon" $delete_attrs><i class="icon-minus-circle"></i></a>
        };
}



=head2 template_id

Returns the template id

=cut

sub template_id {
    my ($self) = @_;
    my $template_id = 'dynamic-list-template.' . $self->id;
    return $template_id;
}

=head2 template_target

Returns the template target

=cut

sub template_target {
    my ($self) = @_;
    return escape_jquery_id($self->template_id);
}

=head2 target_id

return the target id for the element that contains the repeatable elements

=cut

sub target_id {
    my ($self) = @_;
    my $target_id = '#' . escape_jquery_id($self->id);
    if ($self->do_label) {
       $target_id .= " .controls:first";
    }
    return $target_id;
}

=head2 escape_jquery_id

escape a jquery id

=cut

sub escape_jquery_id {
    my ($id) = @_;
    $id =~ s/(:|\.|\[|\]|,|=)/\\$1/g;
    return $id;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


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

