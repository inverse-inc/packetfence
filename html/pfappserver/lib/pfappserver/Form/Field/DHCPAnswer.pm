package pfappserver::Form::Field::DHCPAnswer;

=head1 NAME

pfappserver::Form::Field::DHCPAnswer -

=cut

=head1 DESCRIPTION

pfappserver::Form::Field::DHCPAnswer

=cut

use strict;
use warnings;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler::Field::Compound';
use namespace::autoclean;
use pf::log;

has '+inflate_default_method'=> ( default => sub { \&inflate } );
has '+deflate_value_method'=> ( default => sub { \&deflate } );
has '+widget_wrapper' => (default => 'Bootstrap');
has '+do_label' => (default => 1 );

has_field type => (
    type => 'Select',
    do_label => 0,
    required => 1,
    widget_wrapper => 'None',
    options_method => \&options_type,
    element_class => ['input-medium'],
    localize_labels => 1,
);

has_field value => (
    type => 'Text',
    do_label => 0,
    required => 1,
    widget_wrapper => 'None',
    element_class => ['input-xxlarge'],
);

sub parse_dhcp_answer {
    my ($value) = @_;
    my %hash;
    @hash{qw(type value)} = split(/\s*=\s*/, $value, 2);
    return \%hash;
}

=head2 inflate

inflate the api method spec string to a hash

=cut

sub inflate {
    my ($self, $value) = @_;
    if (ref $value) {
        return $value;
    }
    
    my $hash = parse_dhcp_answer($value) // {};
    return $hash;
}

=head2 deflate

deflate the api method spec hash to a string

=cut

sub deflate {
    my ($self, $value) = @_;
    return join(" = ", $value->{type}, $value->{value});
}

=head2 options_type

Provide a list DHCP option types

=cut

my %options = (
    OptionSubnetMask                                 => 1,
    OptionTimeOffset                                 => 2,
    OptionRouter                                     => 3,
    OptionTimeServer                                 => 4,
    OptionNameServer                                 => 5,
    OptionDomainNameServer                           => 6,
    OptionLogServer                                  => 7,
    OptionCookieServer                               => 8,
    OptionLPRServer                                  => 9,
    OptionImpressServer                              => 10,
    OptionResourceLocationServer                     => 11,
    OptionHostName                                   => 12,
    OptionBootFileSize                               => 13,
    OptionMeritDumpFile                              => 14,
    OptionDomainName                                 => 15,
    OptionSwapServer                                 => 16,
    OptionRootPath                                   => 17,
    OptionExtensionsPath                             => 18,
    OptionIPForwardingEnableDisable                  => 19,
    OptionNonLocalSourceRoutingEnableDisable         => 20,
    OptionPolicyFilter                               => 21,
    OptionMaximumDatagramReassemblySize              => 22,
    OptionDefaultIPTimeToLive                        => 23,
    OptionPathMTUAgingTimeout                        => 24,
    OptionPathMTUPlateauTable                        => 25,
    OptionInterfaceMTU                               => 26,
    OptionAllSubnetsAreLocal                         => 27,
    OptionBroadcastAddress                           => 28,
    OptionPerformMaskDiscovery                       => 29,
    OptionMaskSupplier                               => 30,
    OptionPerformRouterDiscovery                     => 31,
    OptionRouterSolicitationAddress                  => 32,
    OptionStaticRoute                                => 33,
    OptionTrailerEncapsulation                       => 34,
    OptionARPCacheTimeout                            => 35,
    OptionEthernetEncapsulation                      => 36,
    OptionTCPDefaultTTL                              => 37,
    OptionTCPKeepaliveInterval                       => 38,
    OptionTCPKeepaliveGarbage                        => 39,
    OptionNetworkInformationServiceDomain            => 40,
    OptionNetworkInformationServers                  => 41,
    OptionNetworkTimeProtocolServers                 => 42,
    OptionVendorSpecificInformation                  => 43,
    OptionNetBIOSOverTCPIPNameServer                 => 44,
    OptionNetBIOSOverTCPIPDatagramDistributionServer => 45,
    OptionNetBIOSOverTCPIPNodeType                   => 46,
    OptionNetBIOSOverTCPIPScope                      => 47,
    OptionXWindowSystemFontServer                    => 48,
    OptionXWindowSystemDisplayManager                => 49,
    OptionRequestedIPAddress                         => 50,
    OptionIPAddressLeaseTime                         => 51,
    OptionOverload                                   => 52,
    OptionDHCPMessageType                            => 53,
    OptionServerIdentifier                           => 54,
    OptionParameterRequestList                       => 55,
    OptionMessage                                    => 56,
    OptionMaximumDHCPMessageSize                     => 57,
    OptionRenewalTimeValue                           => 58,
    OptionRebindingTimeValue                         => 59,
    OptionVendorClassIdentifier                      => 60,
    OptionClientIdentifier                           => 61,
    OptionNetwareIPDomain                            => 62,
    OptionNetwareIPInformation                       => 63,
    OptionNetworkInformationServicePlusDomain        => 64,
    OptionNetworkInformationServicePlusServers       => 65,
    OptionTFTPServerName                             => 66,
    OptionBootFileName                               => 67,
    OptionMobileIPHomeAgent                          => 68,
    OptionSimpleMailTransportProtocol                => 69,
    OptionPostOfficeProtocolServer                   => 70,
    OptionNetworkNewsTransportProtocol               => 71,
    OptionDefaultWorldWideWebServer                  => 72,
    OptionDefaultFingerServer                        => 73,
    OptionDefaultInternetRelayChatServer             => 74,
    OptionStreetTalkServer                           => 75,
    OptionStreetTalkDirectoryAssistance              => 76,
    OptionUserClass                                  => 77,
    OptionRelayAgentInformation                      => 82,
    OptionClientArchitecture                         => 93,
    OptionTZPOSIXString                              => 100,
    OptionTZDatabaseString                           => 101,
    OptionClasslessRouteFormat                       => 121,
);

sub options_type {
    my ($self) = @_;
    return map {
        {
            value   => $options{$_},
            label   => "$_($options{$_})",
        }
    } sort keys %options
}

pf::api::attributes::updateAllowedAsActions();
 
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

