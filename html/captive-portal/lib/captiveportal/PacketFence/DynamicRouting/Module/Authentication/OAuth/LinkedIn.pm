package captiveportal::PacketFence::DynamicRouting::Module::Authentication::OAuth::LinkedIn;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::OAuth::LinkedIn

=head1 DESCRIPTION

LinkedIn OAuth module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Authentication::OAuth';

has '+token_scheme' => (default => 'uri-query:oauth2_access_token');

has '+source' => (isa => 'pf::Authentication::Source::LinkedInSource');

=head2 _decode_response

The e-mail is returned as a quoted string

=cut

sub _decode_response {
    my ($self, $response) = @_;
    my $pid = $response->content();
    $pid =~ s/"//g;
    return {email => $pid};
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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;

