package pfappserver::Form::Config::Source;

=head1 NAME

pfappserver::Form::Config::Source - Base Web form for auth sources

=head1 DESCRIPTION

Base Form definition to create or update auth sources

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw(
    pfappserver::Base::Form::Role::Help
    pfappserver::Base::Form::Role::AllowedOptions
    pfappserver::Role::Form::RolesAttribute
);

use pfappserver::Form::Field::DynamicList;
use pfappserver::Base::Form::Authentication::Action;

use pf::log;
use pf::authentication;
use pf::Authentication::constants;
use pf::config qw(%connection_group %connection_type);

our %ACTION_FIELD_OPTIONS;

*ACTION_FIELD_OPTIONS = \%pfappserver::Base::Form::Authentication::Action::ACTION_FIELD_OPTIONS;

has source_type => (is => 'ro', builder => '_build_source_type', lazy => 1);

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Name',
   required => 1,
   messages => { required => 'Please specify the name of the source entry' },
   apply => [ pfappserver::Base::Form::id_validator('source name') ],
  );

has_field 'type' => (
   type => 'Hidden',
);

has_field 'description' =>
  (
   type => 'Text',
   label => 'Description',
   required => 1,
   # Default value needed for creating dummy source
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

has_block local_account =>
  (
    render_list => [],
  );

has_block internal_sources =>
  (
    render_list => [],
  );


has_block action_templates => (
    attr => {
        id => 'action_templates',
    },
    class => [qw(hidden)],
    render_list => [
        (map { "${_}_action" } keys %ACTION_FIELD_OPTIONS),
        (map { ("${_}_operator", "${_}_value") } @Conditions::TYPES),
    ],
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
    action_templates => 1,
    local_account => 1,
    create_local_account => 1,
    password_length => 1,
    local_account_logins => 1,
    stripped_user_name => 1,
    realms => 1,
    (map { ("${_}_rules"  => 1) } @Rules::CLASSES),
    (map { ("${_}_action" => 1) } keys %ACTION_FIELD_OPTIONS),
    (map { ("${_}_operator" => 1, "${_}_value" => 1) } @Conditions::TYPES),
);

while (my ($f, $o) = each %ACTION_FIELD_OPTIONS) {
    has_field "${f}_action" => (
        %$o,
        do_wrapper => 0,
        do_label   => 0,
        tags => {
            exclude_from_openapi => 1,
        },
    );
}

## Condition Operators
for my $c (@Conditions::TYPES) {
    has_field "${c}_operator" => (
        type            => 'Select',
        do_label        => 0,
        do_wrapper      => 0,
        localize_labels => 1,
        options_method  => \&operators,
        element_class   => ['span5'],
        tags => {
            exclude_from_openapi => 1,
        },
    );
}

## Condition Text Fields
for my $c ( $Conditions::SUBSTRING, $Conditions::TIME_PERIOD, $Conditions::LDAP_ATTRIBUTE ) {
    has_field "${c}_value" => (
        type          => 'Text',
        do_label      => 0,
        do_wrapper    => 0,
        element_class => ['span8'],
        tags => {
            exclude_from_openapi => 1,
        },
    );
}

has_field "${Conditions::NUMBER}_value" => (
    type          => 'PosInteger',
    do_label      => 0,
    do_wrapper    => 0,
    element_class => ['span8'],
    tags => {
        exclude_from_openapi => 1,
    },
);

has_field "${Conditions::DATE}_value" => (
    type => 'DatePicker',
    do_label => 0,
    do_wrapper => 0,
    tags => {
        exclude_from_openapi => 1,
    },
);

has_field "${Conditions::TIME}_value" => (
    type => 'TimePicker',
    do_label => 0,
    do_wrapper => 0,
    element_class => ['span8'],
    tags => {
        exclude_from_openapi => 1,
    },
);

has_field "${Conditions::CONNECTION}_value" => (
    type => 'Select',
    do_label => 0,
    do_wrapper => 0,
    localize_labels => 1,
    options_method => \&options_connection,
    element_class => ['span8'],
    tags => {
        exclude_from_openapi => 1,
    },
);

=head2 options_connection

Populate the connection types and connection groups field for the
'connection type' condition.

=cut

sub options_connection {
    my $self = shift;

    my @types = map { { value => $_, label => $_ } } sort keys %connection_type;
    my @groups = map { { value => $_, label => $_ } } sort keys %connection_group;

    return
      [
       {
        group => 'Types',
        options => \@types,
        value => '',
       },
       {
        group => 'Groups',
        options => \@groups,
        value => '',
       },
      ];
}

=head2 render_list_definition

Build the render list from the fields defined in the class

=cut

sub render_list_definition {
    my ($self) = @_;
    my @fields =  grep {!exists $EXCLUDE{$_}} map { $_->{name}} $self->all_fields;
    return \@fields;
}


=head2 build_rule_label

build the label of rule

=cut

sub build_rule_label {
    my ($field) = @_;
    my $id = $field->field("id")->value  // "New";
    my $desc = $field->field("description")->value  // "";
    return "Rule - $id ( $desc )";
}

=head2 build_render_list_rules

build the rules to show in the block

=cut

sub build_render_list_rules {
    my ($block) = @_;
    my $source = $block->form->source_class;
    if ($source->has_authentication_rules) {
        my @rules = map { "${_}_rules" } @{$source->available_rule_classes};
        return \@rules;
    }

    return [];
}

=head2 accordion_heading_content

accordion heading content

=cut

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

get the args to build a source

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
    for my $name (keys %$args) {
        my $field = $self->field($name);
        next unless $field;
        # Deflate the duration fields
        # To avoid dummy sources from not being created
        if ($field->type eq 'Duration') {
            my $value = $args->{$name};
            if (ref $value eq 'HASH') {
                $args->{$name} = $field->duration_deflate($value);
            }
        }
    }
    for my $r (qw(realms searchattributes)) {
        $args->{$r} //= [];
        if (ref($args->{$r}) ne "ARRAY" ) {
            $args->{$r} = [$args->{$r}];
        }
    }
    return $args;
}

=head2 operators

Return the appropriate operators for the condition type select field.

=cut

sub operators {
    my $self = shift;

    my ($type) = $self->name =~ m/^(.+)_operator$/;
    my @operators = map { $_ => $self->_localize($_) } @{$Conditions::OPERATORS{$type}};

    return @operators;
}

=head2 validate

validate

=cut

sub validate {
    my ($self) = @_;
    my %rule_names;
    foreach my $class (@{$self->source_class->available_rule_classes}) {
        my $field_name = "${class}_rules";
        my $rules = $self->field($field_name);
        foreach my $rule ($rules->fields) {
            my $id = $rule->field("id");
            my $value = $id->value;
            if (exists $rule_names{$value}) {
                $id->add_error("Rule with id '$value' already exists");
            } else {
                $rule_names{$value}++;
            }
        }
    }
    return ;
}

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
