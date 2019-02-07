package pf::Authentication::SMSRole;

=head1 NAME

pf::Authentication::SMSRole -

=cut

=head1 DESCRIPTION

pf::Authentication::SMSRole

=cut

use strict;
use warnings;
use Moose::Role;

has 'pin_code_length' => (default => 6, is => 'rw', isa => 'Int');

=head2 sendActivationSMS

Send the Activation SMS

=cut

sub sendActivationSMS {
    my ( $self, $pin, $mac ,$message ) = @_;
    require pf::activation;

    my $activation = pf::activation::view_by_code_mac($pf::activation::SMS_ACTIVATION, $pin, $mac);
    my $phone_number = $activation->{'contact_info'};

    return $self->sendSMS({to=> $phone_number, message => $message, activation => $activation});
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
