package pfappserver::Form::Config::RemoteProfile;

=head1 NAME

pfappserver::Form::Config::RemoteProfile - Web form for a floating device

=head1 DESCRIPTION

Form definition to create or update realm.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw (
    pfappserver::Base::Form::Role::Help
    pfappserver::Role::Form::RolesAttribute
);

use pf::config qw(%ConfigAuthenticationLdap %ConfigEAP);
use pf::authentication;
use pf::util;
use pf::ConfigStore::Domain;
use pf::condition_parser qw(parse_condition_string);

## Definition
has_field 'id' =>
  (
    type => 'Text',
    required => 1,
    apply => [ pfappserver::Base::Form::id_validator('profile') ],
    tags => {
       option_pattern => \&pfappserver::Base::Form::id_pattern,
    },
  );

has_field 'description' =>
  (
    type => 'Text',
    required => 1,
  );

has_field 'status' =>
  (
    type => 'Toggle',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
    default => 'enabled'
  );

has_field 'basic_filter_type' =>
  (
    type => 'Select',
    default => '',
    options_method => sub { (
            { value => "", label => "None - use advanced filter" },
            { value => "node_info.mac", label => "Device MAC address" },
            { value => "node_info.pid", label => "Username" },
            { value => "node_info.category", label => "Device Role" },
        ) }
  );

has_field 'basic_filter_value' =>
  (
    type => 'Text',
  );

has_field 'advanced_filter' =>
  (
   type => 'TextArea',
  );

has_field 'allow_communication_same_role' =>
  (
    type => 'Toggle',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
    default => 'enabled'
  );

has_field 'allow_communication_to_roles' =>
  (
   type => 'Select',
   multiple => 1,
   options_method => \&options_roles,
  );

has_field 'resolve_hostnames_of_peers' =>
  (
    type => 'Toggle',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
    default => 'enabled'
  );

has_field 'additional_domains_to_resolve' =>
  (
   type => 'TextArea',
  );

has_field 'internal_domain_to_resolve' =>
  (
   type => 'Text',
    required => 1,
    default => "ztn",
  );

has_field 'gateway' =>
  (
    type => 'Toggle',
    checkbox_value => 'enabled',
    unchecked_value => 'disabled',
    default => 'disabled'
  );

has_field 'routes' =>
  (
   type => 'TextArea',
  );

has_field 'stun_server' =>
  (
    type => 'Text',
    required => 1,
    default => "stun.l.google.com:19302",
  );


sub options_roles {
    my $self = shift;
    my @roles = map { $_->{name} => $_->{name} } @{$self->form->roles} if ($self->form->roles);
    return @roles;
}

sub validate {
    my $self = shift;
    $self->SUPER::validate();

    if($self->field("id")->value eq "default") {
        return;
    }

    if(!$self->field("basic_filter_type")->value && !$self->field("advanced_filter")->value) {
        $self->field("basic_filter_type")->add_error("You need to specify a basic filter or an advanced filter.");
        $self->field("advanced_filter")->add_error("You need to specify a basic filter or an advanced filter.");
    }

    if($self->field("basic_filter_type")->value && $self->field("advanced_filter")->value) {
        $self->field("advanced_filter")->add_error("You cannot specifiy an advanced filter and a basic filter.");
    }

    if($self->field("advanced_filter")->value) {
        my (undef, $error) = parse_condition_string($self->field("advanced_filter")->value);
        if($error) {
            $self->field("advanced_filter")->add_error($error->{message});
        }
    }
}
=over

=back

=head1 COPYRIGHT

Copyright (C) 2005-2020 Inverse inc.

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
