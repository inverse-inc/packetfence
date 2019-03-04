package pfappserver::Form::Field::PfdetectRegexRule;

=head1 NAME

pfappserver::Form::Field::PfdetectRegexRule - The detect::parser::regex rule

=cut

=head1 DESCRIPTION

=cut

use pfappserver::Form::Field::DynamicList;
use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
with 'pfappserver::Base::Form::Role::Help';
use namespace::autoclean;
use pf::util qw(isenabled strip_filename_from_exceptions);

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
    type     => 'RE2',
    label    => 'Regex',
    element_class => ['input-xxlarge'],
    required => 1,
    messages => {required => 'Please specify the regex for the rule'},
);

=head2 actions

The list of action

=cut

has_field 'actions' => (
    'type' => 'DynamicList',
);

=head2 actions.contains

The definition for the list of actions

=cut

has_field 'actions.contains' => (
    type  => 'ApiAction',
    label => 'Action',
    pfappserver::Form::Field::DynamicList::child_options(),
);

=head2 last_if_match

last if match

=cut

has_field 'last_if_match' => (
    type            => 'Toggle',
    label           => 'Last If match',
    checkbox_value  => 'enabled',
    unchecked_value => 'disabled',
    tags => { after_element => \&help, help => 'Stop processing rules if this rule matches'},
);

=head2 ip_mac_translation

If enabled then do ip to mac and mac to ip translation

=cut

has_field 'ip_mac_translation' => (
    type            => 'Toggle',
    label           => 'IP <i class="icon-exchange"></i> MAC',
    default         => 'enabled',
    checkbox_value  => 'enabled',
    unchecked_value => 'disabled',
    tags => {
        after_element => \&help,
        help => 'Perform automatic translation of IPs to MACs and the other way around',
        label_no_filter => 1
    },
);

=head2 validate

Validate the rule is valid

=cut

sub validate {
    my ($self) = @_;
    my $rule = $self->value;
    my $regex = $rule->{regex};
    my $re = eval {
        use re::engine::RE2 -strict => 1;
        qr/$regex/
    };
    if ($@) {
        my $error = strip_filename_from_exceptions($@);
        $error =~ s/(\[|\])/~$1/g;
        $regex =~ s/(\[|\])/~$1/g;
        $self->field('regex')->add_error("Invalid RE2 regex : $error");
        return;
    }

    my $captures = $re->named_captures();
    my $ip_mac_translation = isenabled($rule->{ip_mac_translation});
    foreach my $action_field ($self->field('actions')->fields()) {
        my $api_parameters_field = $action_field->field('api_parameters');
        my $api_parameters = $api_parameters_field->value;
        for my $replace (map {s/^\$//;$_} grep {/^\$/} split(/\s*,\s*/, $api_parameters)) {
            next if exists $captures->{$replace};
            next if $ip_mac_translation && (($replace eq 'mac' && exists $captures->{ip}) || ($replace eq 'ip' && exists $captures->{mac}  ));
            $api_parameters_field->add_error("$replace is not a named capture");
        }
    }

    return;
}

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
