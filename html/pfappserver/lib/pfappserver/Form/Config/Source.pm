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
with 'pfappserver::Base::Form::Role::Help';
use pfappserver::Form::Field::DynamicList;

use pf::log;

has source_type => (is => 'ro', default => 'pf::Authentication::Source');

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Source Name',
   required => 1,
   messages => { required => 'Please specify the name of the source entry' },
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

has_block  definition =>
  (
    render_list => [qw(description rules)],
  );

sub build_rule_label {
    my ($field) = @_;
    my $id = $field->field("id")->value // "New";
    return "Rule - $id";
}

sub accordion_heading_content {
    my ($field) = @_;
    my $content = $field->do_accordion_heading_content;
    my $group_target = $field->escape_jquery_id($field->accordion_group_id);
    my $base_id = $field->parent->id;
    $content .= qq{
        <a class="btn-icon" data-toggle="dynamic-list-delete" data-base-id="$base_id" data-target="#$group_target"><i class="icon-minus-sign"></i></a>};
    return $content;
}

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
