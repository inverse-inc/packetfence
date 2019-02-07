package pfappserver::Form::Widget::Wrapper::Accordion;

=head1 NAME

pfappserver::Form::Widget::Wrapper::Accordion

=cut

=head1 DESCRIPTION

pfappserver::Form::Widget::Wrapper::Accordion

=cut

use Moose::Role;
with 'HTML::FormHandler::Widget::Wrapper::Bootstrap';
use HTML::FormHandler::Render::Util ('process_attrs');
use pf::log;

around wrap_field => sub {
    my ($orig, $self, $result, $rendered_widget ) = @_;
    my $output = '';
    my $parent = $self->parent;
    my $parent_name = $parent->name;
    my $value = $parent->value;
    my $length = $value ? scalar @$value : 0;
    my $name = $self->name;
    my $id = $self->accordion_id;
    my $in  = '';
    my $num_when_empty = $parent->num_when_empty;
    if ( ( $name == 999 || ($name >= $length ) )) {
        $in = 'in';
    }
    my $heading = $self->get_tag("accordion_heading");
    $heading = $self->do_accordion_heading unless $heading;
    my $accordion_group_id  = $self->accordion_group_id;
    $output = <<EOS;
<div class="accordion-group control-group" id="$accordion_group_id">
    $heading
    <div id="$id" class="accordion-body $in collapse">
        <div class="accordion-inner">$rendered_widget</div>
    </div>
</div>
EOS
    return $output;
};

=head2 accordion_id

Returns the accordion id

=cut

sub accordion_id {
    my ($self) = @_;
    return "accordion." . $self->id;
}

=head2 accordion_group_id

Returns the accordion group id

=cut

sub accordion_group_id {
    my ($self) = @_;
    return "accordion.group." . $self->id;
}

=head2 accordion_jq_target

Returns the accordion target

=cut

sub accordion_jq_target {
    my ($self) = @_;
    return $self->escape_jquery_id($self->accordion_id);
}

=head2 escape_jquery_id

Escapes a jquery id

=cut

sub escape_jquery_id {
    my ($self, $id) = @_;
    $id =~ s/(:|\.|\[|\]|,|=)/\\$1/g;
    return $id;
}

=head2 do_accordion_heading

Returns the accordion heading or the tag accordion_heading_content

=cut

sub do_accordion_heading {
    my ($self) = @_;
    my $content = $self->get_tag("accordion_heading_content");
    $content  = $self->do_accordion_heading_content unless $content;
    return <<EOS;
    <div class="accordion-heading">
        $content
    </div>
EOS
}

=head2 do_accordion_heading_content

Returns the accordion heading content

=cut

sub do_accordion_heading_content {
    my ($self) = @_;
    my $label = $self->label;
    my $target = $self->accordion_jq_target;
    my $content = qq{<a data-toggle="collapse" href="#$target">$label</a>};
    my $parent = $self->parent;
    if ($parent && $parent->can("sortable") && $parent->sortable) {
        my $target_id = $parent->target_id;
        my $base_id = $parent->id;
        my $scope = "sortable-" . $base_id;
        my $name = $self->name + 1;
        my $item_target = $self->escape_jquery_id($self->accordion_group_id);
        $content = qq{<span data-sortable-text="$label" data-base-id="$base_id" data-sortable-item="#$item_target" data-sortable-scope="$scope" data-sortable-parent="$target_id" class="sort-handle">$name</span>} .  $content ;
    }
    my $buttons = $self->append_add_delete_buttons;
    $content .= $buttons;
    return $content;
}

=head2 append_add_delete_buttons

Returns the add delete buttons

=cut

sub append_add_delete_buttons {
    my ($self) = @_;
    my $parent = $self->parent;
    my $group_target = $self->escape_jquery_id($self->accordion_group_id);
    my $base_id = $parent->id;
    my $target_wrapper = '#'. $self->escape_jquery_id($base_id);
    my $template_control_group_target = $parent->template_control_group_target;
    my $add_button_attr = $parent->add_button_attr;
    my $delete_button_attrs = qq{data-toggle="dynamic-list-delete" data-template-control-group="${template_control_group_target}" data-target-wrapper="$target_wrapper" data-base-id="$base_id" data-target="#$group_target"};
    my $content = qq{
        <span class="action pull-right">
          <a class="btn-icon" $delete_button_attrs><i class="icon-minus-circle"></i></a>
          <a class="btn-icon" $add_button_attr><i class="icon-plus-circle"></i></a>
        </span>
    };
    return $content;
}

use namespace::autoclean;
1;

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

