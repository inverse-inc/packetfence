package pfappserver::Form::Config::SSLCertificate;

=head1 NAME

pfappserver::Form::Config::SSLCertificate - Web form for an admin role

=head1 DESCRIPTION

Form definition to create or update an admin role

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw(
    pfappserver::Base::Form::Role::Help
);

use pf::admin_roles;
use pf::constants::config;
use pf::Authentication::constants;
use List::MoreUtils qw(all);

## Definition
has_field 'id' => (
    type     => 'Text',
    label    => 'SSL Profile Name',
    required => 1,
    messages => { required => 'Please specify the profile name.' },
);

for my $f (qw(cert key intermediate)) {
    has_field $f => (
        type     => 'TextArea',
        required => 1,
    );
}

has_field ca => (
    type     => 'TextArea',
);

has_field 'private_key_password' => (
    type     => 'Text',
    label    => 'Private Key Password',
    required => 0,
);

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};

1;
