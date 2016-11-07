package pfappserver::Form::Config::Pfdetect::regex;

=head1 NAME

pfappserver::Form::Config::Pfdetect::regex - Web form for a pfdetect detector

=head1 DESCRIPTION

Form definition to create or update a pfdetect detector.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Pfdetect';
with 'pfappserver::Base::Form::Role::Help';
use pf::log;

=head2 rules

The list of rule

=cut

has_field 'rules' => (
    'type' => 'Repeatable',
    do_wrapper => 1,
    do_label => 1,
    tags => {
        after_wrapper => \&append_button,
    },
);

has_field 'rules.contains' => (
    type => 'PfdetectRegexRule',
    widget_wrapper => 'Accordion',
    build_label_method => \&build_rule_label,
    tags => {
        accordion_heading_content => \&accordion_heading_content,
    }
);

sub accordion_heading_content {
    my ($field) = @_;
    my $content = $field->do_accordion_heading_content;
    my $group_target = $field->escape_jquery_id($field->accordion_group_id);
    my $base_id = $field->parent->id;
    $content .= qq{
        <a class="btn-icon" data-toggle="dynamic-list-delete" data-base-id="$base_id" data-target="#$group_target"><i class="icon-minus-sign"></i></a>};
    return $content;
}

=head2 build_rule_label

=cut

sub build_rule_label {
    my ($field) = @_;
    my $name = $field->field("name")->value // "New";
    return "Rule - $name";
}


sub append_button {
    my ($self) = @_;
    my $index = $self->index;
    $self->add_extra(1);
    my $extra_field = $self->field($index);
    set_disabled($extra_field);
    $extra_field->name(999);
    my $id = $self->id;
    my $content = $extra_field->render;
    my $template_id = 'accordion.template.' . $self->id;
    $template_id =~ s/\./_/g;
    my $control_group_id = "${template_id}_control_group";
    return <<"EOS"
    <div class="control-group" id="$control_group_id" >
        <div id="$template_id" class="hidden">$content</div>
        <div>
            <div class="controls">
                <a data-toggle="dynamic-list" data-target="#${id} .controls:first" data-template-parent="#$template_id" data-base-id="$id" class="btn">Add Rule</a>
            </div>
        </div>
    </div>
EOS
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

has_block definition =>
  (
   render_list => [ qw(id type path rules) ],
  );


=over

=back

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

__PACKAGE__->meta->make_immutable;
1;
