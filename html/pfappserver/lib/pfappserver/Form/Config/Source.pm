package pfappserver::Form::Config::Source;

=head1 NAME

pfappserver::Form::Config::Source - Web form for an admin role

=head1 DESCRIPTION

Form definition to create or update an admin role

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help','pfappserver::Base::Form::Role::AllowedOptions';

use pfappserver::Form::Field::DynamicList;

use pf::log;

has source_type => (is => 'ro', builder => '_build_source_type');

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Source Name',
   required => 1,
   messages => { required => 'Please specify the name of the source entry' },
  );

has_field 'type' => (
   type => 'Hidden',
);

has_field 'description' =>
  (
   type => 'Text',
   label => 'Description',
   required => 1,
  );
has_field 'rules' =>
  (
   type => 'DynamicList',
   do_label => 1,
   do_wrapper => 1,
   sortable => 1,
   num_when_empty => 0,
    tags => {
        "dynamic-list-append_controls" => \&rules_add_control,
    }
  );
has_field 'rules.contains' =>
  (
   type => 'SourceRule',
   widget_wrapper => 'Accordion',
   build_label_method => \&build_rule_label,
   pfappserver::Form::Field::DynamicList::child_options(),
   tags => {
        accordion_heading_content => \&accordion_heading_content,
    }
  );

has_block standard =>
  (
    render_list => [qw(type description)],
  );

has_block definition =>
  (
    type => 'Dynamic',
    build_render_list_method => \&build_render_list_definition,
  );

has_block rules =>
  (
    type => 'Dynamic',
    build_render_list_method => \&build_render_list_rules,
  );

=head2 build_render_list_definition

The definition block's render list builder

=cut

sub build_render_list_definition {
    my ($block) = @_;
    return $block->form->render_list_definition;
}

=head2 render_list_definition

Allow the sub forms to defined their own render list for the definition block

=cut

sub render_list_definition { [] }

sub build_rule_label {
    my ($field) = @_;
    my $id = $field->field("id")->value // "New";
    return "Rule - $id";
}

sub build_render_list_rules {
    my ($block) = @_;
    if ($block->form->source_type->has_authentication_rules) {
        return ['rules']
    }

    return [];
}

=head2 rules_add_control

Override the default add button

=cut

sub rules_add_control {
    my ($field) = @_;
    my $attrs  = $field->add_button_attr;
    my $form =  $field->form;
    my $text = $form->_localize("No Rule Defined");
    my $button_text = $form->_localize("Add Rule");
    return qq{
<div class="controls unwell unwell-horizontal">
  <div class="input">
    <p><i class="icon-filter icon-large"></i>$text<br/>
      <a $attrs class="btn" >$button_text</a>
    </p>
  </div>
</div>
};
}


sub accordion_heading_content {
    my ($field) = @_;
    my $content = $field->do_accordion_heading_content;
    my $parent = $field->parent;
    my $group_target = $field->escape_jquery_id($field->accordion_group_id);
    my $base_id = $parent->id;
    my $target_wrapper = '#'. $field->escape_jquery_id($base_id);
    my $template_control_group_target = $parent->template_control_group_target;
    my $add_button_attr = $parent->add_button_attr;
    my $delete_button_attrs = qq{data-toggle="dynamic-list-delete" data-template-control-group="${template_control_group_target}" data-target-wrapper="$target_wrapper" data-base-id="$base_id" data-target="#$group_target"};
    $content .= qq{
        <a class="btn-icon" $delete_button_attrs><i class="icon-minus-sign"></i></a>
        <a class="btn-icon" $add_button_attr><i class="icon-plus-sign"></i></a>
    };
    return $content;
}


=head2 _build_source_type

Build the source type

=cut

sub _build_source_type {
    my ($self) = @_;
    my $source = ref($self) || $self;
    my $source =~ s/^pfappserver::Form::Config::Source:://;
    $source = "pf::Authentication::Source::${source}Source";
    return $source;
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
