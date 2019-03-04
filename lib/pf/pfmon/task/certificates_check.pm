package pf::pfmon::task::certificates_check;

=head1 NAME

pf::pfmon::task::certificates_check

=head1 DESCRIPTION

Check for SSL certificates expiration and alert

=cut

use strict;
use warnings;

use Moose;

use pf::config::util qw(pfmailer);
use pf::constants qw($TRUE $FALSE);
use pf::log;
use pf::util qw(isenabled);
extends qw(pf::pfmon::task);

has 'delay'         => ( is => 'rw', default => "30D" );
has 'certificates'  => ( isa => 'Maybe[Str]', is => 'rw', default => "/usr/local/pf/conf/ssl/server.pem,/usr/local/pf/raddb/certs/server.crt" );

=head2 run

Check for SSL certificates expiration and alert

=cut

sub run {
    my ( $self ) = @_;
    my %problematic_certs = ();
    foreach my $cert (split(/\s*,\s*/, $self->{'certificates'})) {
        if (pf::util::cert_expires_in($cert, $self->delay)) {
            $problematic_certs{$cert}{'expires_soon'} = $TRUE;
            $problematic_certs{$cert}{'expired'} = ( pf::util::cert_expires_in($cert) ) ? $TRUE : $FALSE;
        }
    }

    # Send alerts for problematic certificates
    $self->alert(%problematic_certs) if %problematic_certs;
}

=head2 alert

Sends alerts for problematic SSL certificates

=cut

sub alert {
    my ( $self, %problematic_certs ) = @_;
    my $logger = pf::log::get_logger;

    my $message;
    foreach my $cert ( keys %problematic_certs ) {
        # Alert for expired certificates
        if ( $problematic_certs{$cert}{'expired'} ) {
            $message = "SSL certificate '$cert' is expired. This should be addressed to avoid issues.";
        }
        # Alert for certificates that expires soon
        elsif ( $problematic_certs{$cert}{'expires_soon'} ) {
            $message = "SSL certificate '$cert' is about to expire soon (less than '" . $self->delay . "'). This should be taken care.";
        }
        $logger->warn($message);
        pf::config::util::pfmailer(('subject' => "SSL certificate expiration", 'message' => $message));
    }
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
