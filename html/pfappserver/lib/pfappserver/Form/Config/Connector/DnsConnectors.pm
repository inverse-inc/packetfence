package pfappserver::Form::Config::Connector::DnsConnectors;

=head1 NAME

pfappserver::Form::Config::Connector::DnsConnectors -

=head1 DESCRIPTION

pfappserver::Form::Config::Connector::DnsConnectors

=cut

use strict;
use warnings;
use pf::ConfigStore::Connector::DomainsConnectors;
use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with qw(pfappserver::Base::Form::Role::Help);
## Definition

has_field 'id' => (
    type     => 'Text',
    label    => 'Dns Name',
    required => 1,
    messages => { required => 'Please specify the name of the DNS.' },
);

has_field ip => (
    type     => 'Text',
    label    => 'IP of the dns server',
);

has_field port => (
    type     => 'Text',
    label    => 'Port of the dns server',
);

has_field pfconnectorport => (
    type     => 'Text',
    label    => 'pfconnector port to reach out the dns server',
);

has_field domains => (
    type     => 'Select',
    multiple => 1,
    label    => 'Domain(s) name',
    options_method => \&options_domains,
);

sub options_domains {
    return  map { { value => $_, label => $_ } } @{pf::ConfigStore::Connector::DomainsConnectors->new->readAllIds};
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>

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

1;
