package pfappserver::Form::Config::Source::Stripe;

=head1 NAME

pfappserver::Form::Authentication::Source::Stripe

=cut

=head1 DESCRIPTION

Form definition to create or update a Stripe authentication source.

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
use pf::Authentication::Source::StripeSource;
use pf::log;
extends 'pfappserver::Form::Config::Source::Billing';
with 'pfappserver::Base::Form::Role::Help';

has_field '+currency' => (
    default => 'USD',
);
# Form fields
has_field 'secret_key' => (
    type => 'Text',
    default => '',
);

has_field 'publishable_key' => (
    type => 'Text',
    default => '',
);

has_field 'style' => (
    type    => 'Select',
    default => 'charge',
    options => [{label => 'Charge', value => 'charge'}, {label => 'Subscription', value => 'subscription'}],
    tags => { after_element => \&help,
              help => 'The type of payment the user will make. Charge is a one time fee, subscription will be a recurring fee.' },
);

has_field 'domains' =>
  (
   type => 'Text',
   label => 'Authorized domains',
   required => 1,
   default => pf::Authentication::Source::StripeSource->meta->get_attribute('domains')->default,
   element_attr => {'placeholder' => pf::Authentication::Source::StripeSource->meta->get_attribute('domains')->default},
   element_class => ['input-xlarge'],
   tags => { after_element => \&help,
             help => 'Comma separated list of domains that will be resolve with the correct IP addresses.' },
  );

=head2 currencies

The list of currencies for Stripe

=cut

sub currencies {
    qw(
      AED AFN ALL AMD ANG AOA ARS AUD AWG AZN
      BAM BBD BDT BGN BIF BMD BND BOB BRL BSD
      BWP BZD CAD CDF CHF CLP CNY COP CRC CVE
      CZK DJF DKK DOP DZD EGP ETB EUR FJD FKP
      GBP GEL GIP GMD GNF GTQ GYD HKD HNL HRK
      HTG HUF IDR ILS INR ISK JMD JPY KES KGS
      KHR KMF KRW KYD KZT LAK LBP LKR LRD LSL
      MAD MDL MGA MKD MMK MNT MOP MRO MUR MVR
      MWK MXN MYR MZN NAD NGN NIO NOK NPR NZD
      PAB PEN PGK PHP PKR PLN PYG QAR RON RSD
      RUB RWF SAR SBD SCR SEK SGD SHP SLL SOS
      SRD STD SVC SZL THB TJS TOP TRY TTD TWD
      TZS UAH UGX USD UYU UZS VND VUV WST XAF
      XCD XOF XPF YER ZAR ZMW
    );
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
