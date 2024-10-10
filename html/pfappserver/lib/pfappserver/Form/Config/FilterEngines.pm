package pfappserver::Form::Config::FilterEngines;

=head1 NAME

pfappserver::Form::Config::FilterEngines -

=head1 DESCRIPTION

pfappserver::Form::Config::FilterEngines

=cut

use strict;
use warnings;
use pfappserver::Form::Field::DynamicList;
use HTML::FormHandler::Moose;
use pf::constants::role qw(@ROLES);
use pf::constants::config qw(%connection_type);
use pf::nodecategory;
use pf::constants::eap_type qw(%RADIUS_EAP_TYPE_2_VALUES);
extends 'pfappserver::Base::Form';
with qw(
    pfappserver::Base::Form::Role::Help
);

has_field 'id' => (
    type     => 'Text',
    label    => 'Rule Name',
    required => 1,
);

has_field 'description' => (
    type     => 'Text',
    required => 1,
);

has_field 'condition' => (
    type => 'FilterCondition',
    required => 1,
);

has_field 'status' => (
   type => 'Toggle',
   label => 'Enable Rule',
   checkbox_value => 'enabled',
   unchecked_value => 'disabled',
   default => 'enabled'
);

has_field 'scopes' => (
    type     => 'Select',
    multiple => 1,
    options_method => \&option_scopes,
    required => 1,
);

our %connection_type_field_options = (
    siblings => {
        value => {
            allowed_values =>
              [ map { { text => $_, value => $_ } } keys %connection_type ],
        },
    },
);

our %ADDITIONAL_FIELD_OPTIONS = (
    'node_info.category' => sub {
        siblings => {
            value => {
                allowed_values => [
                    map { { text => $_->{name}, value => $_->{name} } }
                      nodecategory_view_all()
                ],
            },
        },
    },
    'node_info.autoreg' => {
        siblings => {
            value => {
                allowed_values =>
                  [ map { { text => $_, value => $_ } } ( "yes", "no" ) ],
            },
        },
    },
    'node_info.status' => {
        siblings => {
            value => {
                allowed_values => [
                    map { { text => $_, value => $_ } }
                      ( "reg", "unreg", "pending" )
                ],
            },
        },
    },
    'node_info.last_connection_type' => \%connection_type_field_options,
    'connection_type'                => \%connection_type_field_options,
    'connection_sub_type'            => {
        siblings => {
            value => {
                allowed_values => [ map { { text => $_, value => $_  } } keys %RADIUS_EAP_TYPE_2_VALUES  ],
            }
        },
    },
    'compliant_check' => {
        siblings => {
            value => {
                allowed_values => [
                    { text => 'compliant',    value => 1 },
                    { text => 'noncompliant', value => 0 },
                ],
            },
            op => {
                allowed => [
                    {
                        "requires" => [ "value", "field" ],
                        "text"     => "equals",
                        "value"    => "equals"
                    },
                    {
                        "requires" => [ "value", "field" ],
                        "text"     => "not_equals",
                        "value"    => "not_equals"
                    },
                ],
            },
        },
      },
);

sub option_scopes {
    my ($f) = @_;
    return $f->form->scopes();
}

sub option_fields {}

sub make_field_options {
    my ($self, $name) = @_;
    my %options = (
        label => $name,
        value => $name,
        $self->additional_field_options($name),
    );
    return \%options;
}

sub options_field {
    my ($self) = @_;
    return map { $self->make_field_options($_) } $self->options_field_names();
}

sub options_field_names {}

sub _additional_field_options {
    {}
}

sub scopes { }

sub additional_field_options {
    my ($self, $name) = @_;
    my $options = $self->_additional_field_options;
    if (!exists $options->{$name}) {
        return;
    }

    my $more = $options->{$name};
    my $ref = ref $more;
    if ($ref eq 'HASH') {
        return %$more;
    } elsif ($ref eq 'CODE') {
        return $more->($self, $name);
    }

    return;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

