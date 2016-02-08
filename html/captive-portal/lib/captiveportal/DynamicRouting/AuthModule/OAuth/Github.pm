package captiveportal::DynamicRouting::AuthModule::OAuth::Github;

=head1 NAME

captiveportal::DynamicRouting::AuthModule::OAuth::Github

=head1 DESCRIPTION

Github OAuth module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::AuthModule::OAuth';

has '+source' => (isa => 'pf::Authentication::Source::GithubSource');

has '+token_scheme' => (default => sub{"uri-query:access_token"});

sub _extract_username_from_response {
    my ($self, $info) = @_;
    return $info->{email} || $info->{login}.'@github';
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

