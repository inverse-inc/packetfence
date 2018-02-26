package pf::Switch::Aruba::5400;

=head1 NAME

pf::Switch::Aruba::5400

=head1 SYNOPSIS

Module to manage rebanded Aruba HP 5400 switches

=head1 STATUS

=over

=item Supports

=over

=item linkUp / linkDown mode

=item port-security

=item MAC-Authentication

=item 802.1X

=back

=back


=head1 BUGS AND LIMITATIONS

=cut

use strict;
use warnings;
use Net::SNMP;

use base ('pf::Switch::HP::Procurve_5400');

use pf::constants;
use pf::config qw(
    $MAC
    $PORT
);
use pf::Switch::constants;
use pf::util;

sub description { 'Aruba 5400 Switch' }

=over

Return radius attributes to allow write access

=cut

sub returnAuthorizeWrite {
   my ($self, $args) = @_;
   my $logger = $self->logger;
   my $radius_reply_ref = {};
   my $status;
   $radius_reply_ref->{'Service-Type'} = 'Administrative-User';
   $radius_reply_ref->{'Reply-Message'} = "Switch enable access granted by PacketFence";
   $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with write access");
   my $filter = pf::access_filter::radius->new;
   my $rule = $filter->test('returnAuthorizeWrite', $args);
   ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
   return [$status, %$radius_reply_ref];
}

=item returnAuthorizeRead

Return radius attributes to allow read access

=cut

sub returnAuthorizeRead {
   my ($self, $args) = @_;
   my $logger = $self->logger;
   my $radius_reply_ref = {};
   my $status;
   $radius_reply_ref->{'Service-Type'} = 'NAS-Prompt-User';
   $radius_reply_ref->{'Reply-Message'} = "Switch read access granted by PacketFence";
   $logger->info("User $args->{'user_name'} logged in $args->{'switch'}{'_id'} with read access");
   my $filter = pf::access_filter::radius->new;
   my $rule = $filter->test('returnAuthorizeRead', $args);
   ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
   return [$status, %$radius_reply_ref];
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

1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
