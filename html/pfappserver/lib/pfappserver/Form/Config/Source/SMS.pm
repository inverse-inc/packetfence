package pfappserver::Form::Config::Source::SMS;

=head1 NAME

pfappserver::Form::Config::Source::SMS - Web form for SMS-based self-registration

=head1 DESCRIPTION

Form definition to create or update an SMS-verified user source.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Source';
with 'pfappserver::Base::Form::Role::Help';
with 'pfappserver::Base::Form::Role::SourceLocalAccount';

use pf::Authentication::Source::SMSSource;
use pf::sms_carrier;

# Form fields
has_field 'sms_carriers' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'SMS Carriers',
   default_method => \&default_sms_carriers,
   element_class => ['chzn-select', 'input-xxlarge'],
   element_attr => {'data-placeholder' => 'Click to add a carrier' },
   tags => { after_element => \&help,
             help => 'List of phone carriers available to the user' },
  );

has_field 'sms_activation_timeout' =>
  (
   type => 'Duration',
   label => 'SMS Activation Timeout',
   required => 1,
   default => pfappserver::Form::Field::Duration->duration_inflate(pf::Authentication::Source::SMSSource->meta->get_attribute('sms_activation_timeout')->default),
   tags => { after_element => \&help,
             help => 'This is the delay given to a guest who registered by SMS confirmation to fill the PIN code.' },
  );

has_field 'message' =>
(
    type => 'TextArea',
    label => 'SMS text message ($pin will be replaced by the PIN number)',
    default => pf::Authentication::Source::SMSSource->meta->get_attribute('message')->default,
);
has_field 'pin_code_length' =>
  (
   type => 'PosInteger',
   label => 'PIN length',
   required => 1,
   default  => pf::Authentication::Source::SMSSource->meta->get_attribute('pin_code_length')->default,
   tags => { after_element => \&help,
             help => 'The amount of digits of the PIN number.' },
  );
=head1 METHODS

=head2 options_sms_carriers

Retrieve the SMS carriers from the database.

=cut

sub options_sms_carriers {
    my $self = shift;

    my $ref = sms_carrier_view_all();
    my @carriers = map { $_->{id} => $_->{name} } @{$ref} if ($ref);

    return @carriers;
}

=head2 default_sms_carriers

By default, select all the SMS carriers.

=cut

sub default_sms_carriers {
    my $self = shift;

    my @all_carriers = map { $_->{value} } @{$self->field('sms_carriers')->options};

    return \@all_carriers;
}

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
