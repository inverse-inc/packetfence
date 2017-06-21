package pfappserver::Form::Field::SourceRule;

=head1 NAME

pfappserver::Form::Field::SourceRule - Rules of a user source

=head1 DESCRIPTION

Form definition to manage the rules (conditions and actions) of an
authentication source.

=cut

use pfappserver::Form::Field::DynamicList;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';

use pf::Authentication::constants;


# Form select options
has 'rule_class' => (is => 'ro');

# Form fields
has_field 'id' => (
    type     => 'Text',
    label    => 'Name',
    required => 1,
    messages => {required => 'Please specify an identifier for the rule.'},
    apply    => [{check => qr/^\S+$/, message => 'The name must not contain spaces.'}],
);

has_field 'description' => (
    type     => 'Text',
    label    => 'Description',
    required => 0,
);

has_field 'match' => (
    type            => 'Select',
    localize_labels => 1,
    label           => 'Matches',
    options         => [
        {value => $Rules::ALL, label => 'all'},
        {value => $Rules::ANY, label => 'any'},
    ],
    default         => $Rules::ALL,
    element_class   => ['input-mini'],
);

has_field 'conditions' => (
    type     => 'DynamicList',
    do_label => 1,
    sortable => 1,
    num_when_empty => 0,
    tags => {
        "dynamic-list-append_controls" => \&condition_control
    }
);

has_field 'conditions.contains' => (
    type  => 'SourceRuleCondition',
    label => 'Condition',
    pfappserver::Form::Field::DynamicList::child_options(),
);

has_field 'actions' => (
    type     => 'DynamicList',
    do_label => 1,
    required => 1,
    sortable => 1,
    num_when_empty => 1,
);

has_field 'actions.contains' => (
    type  => 'SourceRuleAction',
    label => 'Action',
    pfappserver::Form::Field::DynamicList::child_options(),
);


=head2 condition_control

Override the default add button

=cut

sub condition_control {
    my ($field) = @_;
    my $attrs  = $field->add_button_attr;
    my $form =  $field->form;
    my $text = $form->_localize("Without condition, this rule will act as a catch-all.");
    my $button_text = $form->_localize("Add a condition.");
    return qq{<div class="unwell unwell-horizontal">
          <p><i class="icon-filter icon-large"></i>$text<br/>
          <a $attrs class="btn" >$button_text</a></p></div>};
}

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

__PACKAGE__->meta->make_immutable;

1;
