package pfappserver::Form::Config::TemplateSwitch;

=head1 NAME

pfappserver::Form::Config::TemplateSwitch - Web form for a floating device

=head1 DESCRIPTION

Form definition to create or update a floating network device.

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::config;
use pf::util;
use pf::constants::template_switch qw(
  $DISCONNECT_TYPE_COA
  $DISCONNECT_TYPE_DISCONNECT
  $DISCONNECT_TYPE_BOTH
  @RADIUS_ATTRIBUTE_SETS
);

## Definition
has_field 'id' => (
    type     => 'Text',
    required => 1,
);

has_field 'description' => (
    type     => 'Text',
    required => 1,
);

has_field 'radiusDisconnect' => (
    type    => 'Select',
    label   => 'RADIUS Disconnect Method',
    options => [
        { value => $DISCONNECT_TYPE_COA, label => $DISCONNECT_TYPE_COA },
        { value => $DISCONNECT_TYPE_DISCONNECT, label => $DISCONNECT_TYPE_DISCONNECT },
        { value => $DISCONNECT_TYPE_BOTH, label => $DISCONNECT_TYPE_BOTH },
    ],
);


for my $n (@RADIUS_ATTRIBUTE_SETS) {
    has_field $n => (
       type => 'Repeatable',
       num_when_empty => 0,
       num_extra => 0,
    );

    has_field "$n.contains" => (
        type => 'RadiusAttribute'
    );
}

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
