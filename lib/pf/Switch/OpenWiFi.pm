package pf::Switch::OpenWiFi;


=head1 NAME

pf::Switch::OpenWiFi

=head1 SYNOPSIS

The pf::Switch::OpenWiFi module manages access to OpenWiFi

=head1 STATUS

Should work on the OpenWiFi

=cut

use strict;
use warnings;

use base ('pf::Switch::Hostapd');

use pf::util::wpa;
use pf::constants qw($TRUE $FALSE);
use pf::log;

sub description { 'OpenWiFi' }

=item returnRadiusAccessAccept

Prepares the RADIUS Access-Accept reponse for the network device.
Overrides the default implementation to add the dynamic PSK

=cut

sub returnRadiusAccessAccept {
    my ($self, $args) = @_;
    my $logger = $self->logger;

    $args->{'unfiltered'} = $TRUE;
    my @super_reply = @{$self->SUPER::returnRadiusAccessAccept($args)};
    my $status = shift @super_reply;
    my %radius_reply = @super_reply;
    my $radius_reply_ref = \%radius_reply;
    return [$status, %$radius_reply_ref] if($status == $RADIUS::RLM_MODULE_USERLOCK);

    if ($args->{profile}->dpskEnabled()) {
        if (defined($args->{owner}->{psk})) {
            $radius_reply_ref->{"Tunnel-Password"} = $args->{owner}->{psk};
        } else {
            $radius_reply_ref->{"Tunnel-Password"} = $args->{profile}->{_default_psk_key};
        }
    }
    
    my $filter = pf::access_filter::radius->new;
    my $rule = $filter->test('returnRadiusAccessAccept', $args);
    ($radius_reply_ref, $status) = $filter->handleAnswerInRule($rule,$args,$radius_reply_ref);
    return [$status, %$radius_reply_ref];
}

sub find_user_by_psk {
    my ($self, $radius_request) = @_;

    my ($status, $iter) = pf::dal::person->search(
        -where => {
            psk => {'!=' => [-and => '', undef]},
        },
    );

    my $matched = 0;
    my $pid;
    while(my $person = $iter->next) {
        get_logger->debug("User ".$person->{pid}." has a PSK. Checking if it matches the one in the packet");
        if($self->check_if_radius_request_psk_matches($radius_request, $person->{psk})) {
            get_logger->info("PSK matches the one of ".$person->{pid});
            $matched ++;
            $pid = $person->{pid};
        }
    }

    if($matched > 1) {
        get_logger->error("Multiple users use the same PSK. This cannot work with unbound DPSK. Ignoring it.");
        return undef;
    }
    else {
        return $pid;
    }
}

sub check_if_radius_request_psk_matches {
    my ($self, $radius_request, $psk) = @_;

    my @parts = split(":", $radius_request->{"Called-Station-Id"});
    my $ssid = pop @parts;
    my $bssid = join("", @parts);
    $bssid =~ s/-//g;

    my $pmk = $self->cache->compute(
        "OpenWiFi::check_if_radius_request_psk_matches::PMK::$ssid+$psk", 
        "1 month",
        sub { pf::util::wpa::calculate_pmk($ssid, $psk) },
    );

    return pf::util::wpa::match_mic(
      pf::util::wpa::calculate_ptk(
        $pmk,
        pack("H*", $bssid),
        pack("H*", $radius_request->{"User-Name"}),
        pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{"FreeRADIUS-802.1X-Anonce"})),
        pf::util::wpa::snonce_from_eapol_key_frame(pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{"FreeRADIUS-802.1X-EAPoL-Key-Msg"}))),
      ),      
      pack("H*", pf::util::wpa::strip_hex_prefix($radius_request->{"FreeRADIUS-802.1X-EAPoL-Key-Msg"})),
    );
}

=back

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
