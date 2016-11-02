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
    do_label => 1,
    tags => {
        after_element => \&append_button,
    },
);

has_field 'rules.contains' => (
    type => 'PfdetectRegexRule',
    widget_wrapper => 'Accordion',
    label => 'Rule',
);

sub append_button {
    my ($self) = @_;
    my $index = $self->index;
    $self->add_extra(1);
    my $extra_field = $self->field($index);
    set_disabled($extra_field);
    my $content = $self->field($index)->render;
    return qq{<div><div id="template-rules" class="hidden">$content</div><button class="btn">Add Rule</button></div>};
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
