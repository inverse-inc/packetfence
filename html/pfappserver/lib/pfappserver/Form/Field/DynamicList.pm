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
            input_append => \&append_delete_button
        }
    );
}

sub build_init_contains {
    {
        child_options()
    }
}

sub append_add_button {
    my ($self) = @_;
    my $extra_field = $self->_add_extra(999);
    set_disabled($extra_field);
    my $id = $self->id;
    my $button_text = "Add " . $extra_field->label;
    my $content = $extra_field->render;
    # remove extra result & field, now that it's rendered
    $self->result->_pop_result;
    $self->_pop_field;
    my $template_id = $self->template_id;
    my $template_target = $self->template_target;
    my $target = $self->target_id;
    my $control_group_id = "${template_id}_control_group";
    return <<"EOS"
    <div class="control-group" id="$control_group_id" >
        <div id="$template_id" class="hidden">$content</div>
        <div>
            <div class="controls">
                <a data-toggle="dynamic-list" data-target="${target}" data-template-parent="#$template_target" data-base-id="$id" class="btn">$button_text</a>
            </div>
        </div>
    </div>
EOS
}

sub append_delete_button {
    my ($field) = @_;
    my $target = escape_jquery_id($field->id);
    my $base_id = $field->parent->id;
    return qq{
        <a class="btn-icon" data-toggle="dynamic-list-delete" data-base-id="$base_id" data-target="#$target"><i class="icon-minus-sign"></i></a>};
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

Copyright (C) 2005-2016 Inverse inc.

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

