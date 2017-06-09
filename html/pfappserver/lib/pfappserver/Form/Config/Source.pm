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
use pf::authentication;

has source_type => (is => 'ro', builder => '_build_source_type', lazy => 1);

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Name',
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
   default => '',
  );

has_field "${Rules::AUTH}_rules" =>
  (
   type => 'DynamicList',
   label => 'Authentication Rules',
   do_label => 1,
   do_wrapper => 1,
   sortable => 1,
   num_when_empty => 0,
    tags => {
        "dynamic-list-append_controls" => \&rules_add_control,
    }
  );

has_field "${Rules::AUTH}_rules.contains" =>
  (
   type => 'SourceRule',
   widget_wrapper => 'Accordion',
   build_label_method => \&build_rule_label,
   rule_class => $Rules::AUTH,
   pfappserver::Form::Field::DynamicList::child_options(),
   tags => {
        accordion_heading_content => \&accordion_heading_content,
    }
  );

has_field "${Rules::ADMIN}_rules" =>
  (
   type => 'DynamicList',
   label => 'Administration Rules',
   do_label => 1,
   do_wrapper => 1,
   sortable => 1,
   num_when_empty => 0,
    tags => {
        "dynamic-list-append_controls" => \&rules_add_control,
    }
  );

has_field "${Rules::ADMIN}_rules.contains" =>
  (
   type => 'SourceRule',
   widget_wrapper => 'Accordion',
   build_label_method => \&build_rule_label,
   rule_class => $Rules::ADMIN,
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

our %EXCLUDE = (
    id => 1,
    type => 1,
    description => 1,
    rules => 1,
);

=head2 render_list_definition

Build the render list from the fields defined in the class

=cut

sub render_list_definition {
    my ($self) = @_;
    my @fields =  grep {!exists $EXCLUDE{$_}} map { $_->{name}} $self->all_fields;
    return \@fields;
}

sub build_rule_label {
    my ($field) = @_;
    my $id = $field->field("id")->value // "New";
    return "Rule - $id";
}

sub build_render_list_rules {
    my ($block) = @_;
    my $source = $block->form->source_class;
    if ($source->has_authentication_rules) {
        my @rules = map { "${_}_rules" } @{$source->available_rule_classes};
        return \@rules;
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
    my $label = $field->label;
    my $text = $form->_localize("No $label");
    my $button_text = $form->_localize("Add Rule");
    return qq{
<div class="pull-left">
  <p>
   <i class="icon-cogs icon-large"></i> $text<br/>
   <a $attrs class="btn" >$button_text</a>
  </p>
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
    $source =~ s/^\Qpfappserver::Form::Config::Source::\E//;
    return $source;
}

=head2 source_class

Build the source type

=cut

sub source_class {
    my ($self) = @_;
    my $type = $self->source_type;
    my $class = "pf::Authentication::Source::${type}Source";
    return $class;
}


=head2 get_source

Get the source

=cut

sub get_source {
    my ($self) = @_;
    my $args = $self->getSourceArgs;
    my $source_type = $self->source_type;
    return newAuthenticationSource($source_type, 'source', { %$args, id => 'source', rules =>[]});
}


=head2 getSourceArgs

get the source args

=cut

sub getSourceArgs {
    my ($self) = @_;
    my $args = $self->value;
    if (!defined ($args) || keys %$args == 0 ) {
        $args = $self->params;
    }
    if (!defined ($args) || keys %$args == 0 ) {
        $args = $self->init_object;
    }
    return $args;
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
