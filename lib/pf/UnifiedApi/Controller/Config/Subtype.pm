package pf::UnifiedApi::Controller::Config::Subtype;

=head1 NAME

pf::UnifiedApi::Controller::Config::Subtype -

=cut

=head1 DESCRIPTION

pf::UnifiedApi::Controller::Config::Subtype

=cut

use strict;
use warnings;
use Mojo::Base qw(pf::UnifiedApi::Controller::Config);
use pf::error qw(is_error);

sub form_class_by_type {
    my ($self, $type) = @_;
    my $lookup = $self->type_lookup;
    return exists $lookup->{$type} ? $lookup->{$type} : undef;
}

sub form {
    my ($self, $item, @args) = @_;
    my $type = $item->{type};
    if ( !defined $type ) {
        return 422, "Unable to validate: 'type field is required'";
    }

    my $class = $self->form_class_by_type($type);
    if ( !$class  ){
        return 422, "Unable to validate: 'type field is invalid '$type''";
    }
    my $parameters = $self->form_parameters($item);
    if (!defined $parameters) {
        return 422, "Invalid requests";
    }

    return 200, $class->new(@$parameters, @args, user_roles => $self->stash->{'admin_roles'});
}

sub type_lookup {
    return {}
}

sub cached_form_key {
    my ($self, $item, @args) = @_;
    my $type = $item->{type};
    return "cached_form_$type";
}

=head2 options

Handle the OPTIONS HTTP method

=cut

sub options {
    my ($self) = @_;
    my $params = $self->req->query_params->to_hash;
    my ($status, $form) = $self->form( { type => $params->{type} } );
    return $self->render(
        json => (
              is_error($status)
            ? $self->options_with_no_type
            : $self->options_from_form($form, $self->default_values)
        ),
        status => 200
    );
}

=head2 options_with_no_type

Return options with no type information

=cut

sub options_with_no_type {
    my ($self) = @_;
    my %output = (
        meta => {
            type => {
                allowed => [
                    map { $self->type_allowed_info($_) } keys %{$self->type_lookup}
                ],
                type => "string",
            },
        }
    );

    return \%output;
}

=head2 type_allowed_info

Create the type's allowed info

=cut

sub type_allowed_info {
    my ($self, $type) = @_;
    return {
        value => $type,
        text => $type,
    };
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
