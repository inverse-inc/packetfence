package pfappserver::Form::Field::PfdetectRegexRule;

=head1 NAME

pfappserver::Form::Field::PfdetectRegexRule - The detect::parser::regex rule

=cut

=head1 DESCRIPTION



=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
use namespace::autoclean;

=head2 name

Name

=cut

has_field 'name' => (
    type     => 'Text',
    label    => 'Name',
    required => 1,
    messages => {required => 'Please specify the name of the rule'},
);

=head2 regex

Regex

=cut

has_field 'regex' => (
    type     => 'Regex',
    label    => 'Regex',
    element_class => ['input-xxlarge'],
    required => 1,
    messages => {required => 'Please specify the regex pattern using named captures'},
);

=head2 events

Events

=cut

has_field 'events' => (
    type  => 'Text',
    label => 'Event List',

    #This is required if the send_add_event if checked
    #Add validation to the event list
    messages => {required => 'Please specify the regex pattern using named captures'},
);

=head2 actions

The list of action

=cut

has_field 'actions' => (
    'type' => 'Repeatable',
    do_wrapper => 1,
    tags => {
        after_wrapper => \&append_add_button,
    },
);

=head2 actions.contains

The definition for the list of actions

=cut

has_field 'actions.contains' => (
    do_wrapper => 1,
    type  => 'ApiAction',
    label => 'Action',
    tags => {
        input_append => \&append_delete_button,
    },
);

=head2 send_add_event

Send Add Event

=cut

has_field 'send_add_event' => (
    type            => 'Toggle',
    label           => 'Send Add Event',
    messages        => {required => 'Please specify the if the add_event is sent'},
    checkbox_value  => 'enabled',
    unchecked_value => 'disabled',
);

=head2 append_add_button


=cut

sub append_add_button {
    my ($self) = @_;
    my $index = $self->index;
    $self->add_extra(1);
    my $extra_field = $self->field($index);
    set_disabled($extra_field);
    $extra_field->name(999);
    my $id = $self->id;
    my $button_text = "Add " . $extra_field->label;
    my $content = $extra_field->render;
    my $template_id = 'dynamic-list-template.' . $self->id;
    $template_id =~ s/\./_/g;
    my $target = escape_jquery_id($id);
    my $control_group_id = "${template_id}_control_group";
    return <<"EOS"
    <div class="control-group" id="$control_group_id" >
        <div id="$template_id" class="hidden">$content</div>
        <div>
            <div class="controls">
                <a data-toggle="dynamic-accordion" data-target="#${target}" data-template-parent="#$template_id" data-base-id="$id" class="btn">$button_text</a>
            </div>
        </div>
    </div>
EOS
}

sub escape_jquery_id {
    my ($id) = @_;
    $id =~ s/(:|\.|\[|\]|,|=)/\\$1/g;
    return $id;
}

sub append_delete_button {
    my ($field) = @_;
    my $target = escape_jquery_id($field->id);
    my $base_id = $field->parent->id;
    return qq{
        <a class="btn-icon" data-toggle="dynamic-list-delete" data-base-id="$base_id" data-target="#$target"><i class="icon-minus-sign"></i></a>};
}


sub set_disabled {
    my ($field) = @_;
    if ($field->can("fields")) {
        foreach my $subfield ($field->fields) {
            set_disabled($subfield);
        }
    }
    $field->set_element_attr("disabled" => "disabled");
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
