package pfappserver::Form::Config::Pfdetect::regex;

=head1 NAME

pfappserver::Form::Config::Pfdetect::regex - Web form for a pfdetect detector

=head1 DESCRIPTION

Form definition to create or update a pfdetect detector.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Pfdetect';
with 'pfappserver::Base::Form::Role::Help';
use pfappserver::Form::Field::DynamicList;
use pf::log;

=head2 rules

The list of rule

=cut

has_field 'rules' => (
    'type' => 'DynamicList',
    do_wrapper => 1,
    sortable => 1,
    do_label => 1,
);

has_field 'rules.contains' => (
    type => 'PfdetectRegexRule',
    widget_wrapper => 'Accordion',
    build_label_method => \&build_rule_label,
    pfappserver::Form::Field::DynamicList::child_options(),
);

has_field 'loglines' => (
    'type' => 'TextArea',
    'is_inactive' => 1,
);

has_field 'lines' => (
    'type' => 'Repeatable',
    'is_inactive' => 1,
);

has_field 'lines.contains' => (
    type => 'Text',
);

=head2 build_rule_label

Build the rule label

=cut

sub build_rule_label {
    my ($field) = @_;
    my $name = $field->field("name")->value // "New";
    return "Rule - $name";
}


has_block definition =>
  (
   render_list => [ qw(id type status path rules) ],
  );


=over

=back

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;
