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

sub build_widget_tags {
    return {
        after_wrapper => \&append_add_button
    };
}

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

sub build_init_contains {
    {
        child_options()
    }
}

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
    return <<"EOS";
    <div class="control-group $cg_hidden" id="$control_group_id" >
        <div id="$template_id" class="hidden">$content</div>
        <div class="controls">$append_controls</div>
    </div>
EOS
}

sub template_control_group_id {
    my ($self) = @_;
    my $template_id = $self->template_id;
    return "${template_id}_control_group";
}

sub template_control_group_target {
    my ($self) = @_;
    return '#' . escape_jquery_id($self->template_control_group_id);
}

sub do_append_controls {
    my ($self, $button_text) = @_;
    my $content  = $self->get_tag("dynamic-list-append_controls");
    return $content if $content;
    my $attrs = $self->add_button_attr;
    return qq{<a$attrs class="btn">$button_text</a>};
}

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

sub target_wrapper {
    my ($self) = @_;
    return '#' . escape_jquery_id($self->id);
}

sub append_delete_button {
    my ($field) = @_;
    my $target = escape_jquery_id($field->id);
    my $parent = $field->parent;
    my $add_attrs = $parent->add_button_attr;
    my $delete_attrs = $parent->delete_button_attr($field);
    return qq{
        <a class="btn-icon" $add_attrs><i class="icon-plus-sign"></i></a>
        </span><span class="add-on">
        <a class="btn-icon" $delete_attrs><i class="icon-minus-sign"></i></a>
        };
}


sub template_id {
    my ($self) = @_;
    my $template_id = 'dynamic-list-template.' . $self->id;
    return $template_id;
}

sub template_target {
    my ($self) = @_;
    return escape_jquery_id($self->template_id);
}

sub target_id {
    my ($self) = @_;
    my $target_id = '#' . escape_jquery_id($self->id);
    if ($self->do_label) {
       $target_id .= " .controls:first";
    }
    return $target_id;
}

sub escape_jquery_id {
    my ($id) = @_;
    $id =~ s/(:|\.|\[|\]|,|=)/\\$1/g;
    return $id;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

