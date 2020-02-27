package captiveportal::DynamicRouting::Module::Authentication::OAuth::Toutatice;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::OAuth::Toutatice

=head1 DESCRIPTION

Toutatice OAuth module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Authentication::OAuth';

has '+source' => (isa => 'pf::Authentication::Source::ToutaticeSource');

has 'token_scheme' => (is => 'rw', default => sub {"auth-header:Bearer"});

=head2 _extract_username_from_response

Take username from sub attribute in response

=cut

sub _extract_username_from_response {
    my ($self, $info) = @_;
    return $info->{sub};
}

=head2 auth_source_params_child

The parameters available for source matching

=cut

sub auth_source_params_child {
    my ($self) = @_;
    my $info = person_view($self->username());
    return {
        title => $info->{title},
        ENTPersonUid => $info->{custom_field_1},
        personalTitle => $info->{custom_field_3}
    };
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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

