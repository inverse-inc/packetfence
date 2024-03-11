package pfappserver::Form::Config::Source::GoogleWorkspaceLDAP;

=head1 NAME

pfappserver::Form::Config::Source::GoogleWorkspaceLDAP -

=head1 DESCRIPTION

pfappserver::Form::Config::Source::GoogleWorkspaceLDAP

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
use pf::Authentication::Source::GoogleWorkspaceLDAPSource;
extends 'pfappserver::Form::Config::Source::LDAP';
our $META = pf::Authentication::Source::GoogleWorkspaceLDAPSource->meta;

#
# Form fields
has_field 'host' => (
    num_when_empty => 1,
    type => 'Repeatable',
    required => 1,
);

has_field 'host.contains' => (
    type => 'Text',
    required => 1,
    default => default_value('host')->[0],
);

has_field '+port' => ( default => default_value('port') );
has_field '+encryption' => (
    default => default_value('encryption'),
    options => [
        { value => 'ssl',      label => 'SSL' },
        { value => 'starttls', label => 'Start TLS' },
    ],
);

has_field '+client_cert_file' => (
    required => 1,
);

has_field '+client_key_file' => (
    required => 1,
);

sub default_value {
    my ($name) = @_;
    my $val = $META->get_attribute($name)->default;
    if (ref($val) eq 'CODE') {
        return $val->();
    }

    return $val
}

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
