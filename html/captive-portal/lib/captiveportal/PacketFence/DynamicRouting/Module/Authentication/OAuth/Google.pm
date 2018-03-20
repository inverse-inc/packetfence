package captiveportal::PacketFence::DynamicRouting::Module::Authentication::OAuth::Google;

=head1 NAME

captiveportal::DynamicRouting::Module::Authentication::OAuth::Google

=head1 DESCRIPTION

Google OAuth module

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::Authentication::OAuth';

use pf::log;
use pf::auth_log;

has '+source' => (isa => 'pf::Authentication::Source::GoogleSource');

=head2 filter_response

Google  override of filter_response to validate hosted domain

=cut

sub filter_response {
    my ($self, $info) = @_;
    # Return accept/reject response and status message to display to the user in case of failure
    
    my $hd = $info->{hd};
    my $hosted_domain = $self->source->hosted_domain;
    my $status = "";
    my $retval = 1;
    if ( defined $hosted_domain && $hosted_domain ne "" && (!defined $hd || $hosted_domain ne $hd)){
        $retval = 0;
        get_logger->debug(sub { use Data::Dumper; "OAuth2 rejected by google OAuth filter_respponse: ".Dumper($info) });
        $status = "Google domain(".$hd.") did not match the allowed domain: ".$hosted_domain ;
    }
    return ($retval,$status);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

