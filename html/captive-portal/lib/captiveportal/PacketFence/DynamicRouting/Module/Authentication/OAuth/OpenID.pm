package captiveportal::PacketFence::DynamicRouting::Module::Authentication::OAuth::OpenID;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::OAuth::OpenID

=head1 DESCRIPTION

OpenID OAuth module

=cut

use Moose;
use pf::person qw(person_view);
extends 'captiveportal::DynamicRouting::Module::Authentication::OAuth';

has '+source' => (isa => 'pf::Authentication::Source::OpenIDSource');

has 'token_scheme' => (is => 'rw', default => sub {"auth-header:Bearer"});

=head2 _extract_username_from_response

Extract the username from the response of the provider

=cut

sub _extract_username_from_response {
    my ($self, $info) = @_;
    my $source = $self->source;
    my $username = $source->username_attribute;
    if (!exists $info->{$username}) {
        return $self->SUPER::_extract_username_from_response($info);
    }

    return $info->{$source->username_attribute} // $self->SUPER::_extract_username_from_response($info);
}

sub auth_source_params_child {
    my ($self) = @_;
    my $info = person_view($self->username());
    return $self->source->map_from_person($info);
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

