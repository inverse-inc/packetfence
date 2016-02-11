package captiveportal::DynamicRouting::Form::Authentication;

=head1 NAME

DynamicRouting::RenderingMap

=head1 DESCRIPTION

Application definition for Dynamic Routing

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';

has 'app' => (is => 'rw', isa => 'captiveportal::DynamicRouting::Application', required => 1);

has '+field_name_space' => ( default => 'captiveportal::DynamicRouting::Form::Field' );
has '+widget_name_space' => ( default => 'captiveportal::DynamicRouting::Form::Widget' );

use pf::log;
use pf::sms_carrier;

has 'source' => (is => 'rw');

my %skip = (
    email => 1,
    pid => 1,
    sponsor => 1,
    portal => 1,
    source => 1,
);
foreach my $field (@pf::person::FIELDS){
    next if(exists($skip{$field}));
    has_field "fields[$field]" => (type => 'Text');
}

has_field 'fields[username]' => (type => 'Text', label => 'Username');

has_field 'fields[password]' => (type => 'Password', label => 'Password');

has_field 'fields[email]' => (type => "Email", label => "Email");

has_field 'fields[sponsor]' => (type => "Email", label => "Sponsor Email");

has_field 'fields[mobileprovider]' => (type => "Select", label => "Mobile provider", options_method => \&sms_carriers);

has_field 'fields[aup]' => (type => 'AUP', validate_method => \&check_aup);

sub check_aup {
    my ($self) = @_;
    get_logger->info("AUP value is : ".$self->value);
    unless($self->value){
        $self->add_error("You must accept the terms and conditions");
        $self->form->app->flash->{error} = "You must accept the terms and conditions";
    }
}

sub get_field {
    my ($self, $name) = @_;
    $name = "fields[".$name."]";
    return $self->field($name) || die "Can't build field $name";
}

sub sms_carriers {
    my ($self) = @_;
    return map { $_->{id} => $_->{name} } @{sms_carrier_view_all()};
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


