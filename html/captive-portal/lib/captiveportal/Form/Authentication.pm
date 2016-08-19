package captiveportal::Form::Authentication;

=head1 NAME

captiveportal::Form::Authentication

=head1 DESCRIPTION

Form definition for the Authentication on the portal

=cut

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';

has 'app' => (is => 'rw', isa => 'captiveportal::DynamicRouting::Application', required => 1);
has 'module' => (is => 'rw', isa => 'captiveportal::DynamicRouting::Module', required => 1);

has '+field_name_space' => ( default => 'captiveportal::Form::Field' );
has '+widget_name_space' => ( default => 'captiveportal::Form::Widget' );

use pf::log;
use pf::sms_carrier;
use pf::util;

has 'source' => (is => 'rw');

my %skip = (
    email => 1,
    map { $_ => 1 } @pf::person::NON_PROMPTABLE_FIELDS,
);
foreach my $field (@pf::person::FIELDS){
    next if(exists($skip{$field}));
    has_field "fields[$field]" => (type => 'Text', label => ucfirst($field));
}

has_field 'fields[username]' => (type => 'Text', label => 'Username', element_attr => { autocorrect => "off", autocapitalize => "off" });

has_field 'fields[password]' => (type => 'Password', label => 'Password');

has_field 'fields[email]' => (type => "Email", label => "Email");

has_field 'fields[sponsor]' => (type => "Email", label => "Sponsor Email");

has_field 'fields[mobileprovider]' => (type => "Select", label => "Mobile provider", options_method => \&sms_carriers, empty_select => '---Choose a Provider---');

has_field 'fields[aup]' => (type => 'AUP', id => 'aup', validate_method => \&check_aup);

has_field 'fields[email_instructions]' => (type => 'Display', set_html => 'render_email_instructions');

=head2 render_email_instructions

Render the instructions for e-mail registration

=cut

sub render_email_instructions {
    my ($self) = @_;
    my $current_module = $self->form->module;
    my $email_timeout;
    if(defined($current_module) && $current_module->isa("captiveportal::DynamicRouting::Module::Authentication") && $current_module->source->isa("pf::Authentication::Source::EmailSource")){
        $email_timeout = normalize_time($current_module->source->email_activation_timeout);
        $email_timeout = $email_timeout / 60 . " minutes";
    }
    return 
        "<div class='text-center'>".$self->app->i18n("After registering, you will be given temporary network access".(defined($email_timeout) ? " during $email_timeout" : "").". In order to complete your registration, you will need to click on the link emailed to you.")."</div>" .
        "<input name='fields[email_instructions]' type='hidden' value='1'>";
}

=head2 check_aup

Check that the AUP has been properly accepted

=cut

sub check_aup {
    my ($self) = @_;
    if($self->form->module->with_aup && $self->form->app->request->method eq "POST"){
        get_logger->debug("AUP is required and it's value is : ".$self->value);
        unless($self->value){
            $self->add_error("You must accept the terms and conditions");
            $self->form->app->flash->{error} = "You must accept the terms and conditions";
        }
    }
}

=head2 get_field

Get a field following the standard field[$name] by its name 

=cut

sub get_field {
    my ($self, $name) = @_;
    $name = "fields[".$name."]";
    return $self->field($name) || die "Can't build field $name";
}

=head2 sms_carriers

The SMS carriers that are available

=cut

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


