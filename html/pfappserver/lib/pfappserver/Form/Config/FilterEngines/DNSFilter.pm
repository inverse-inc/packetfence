package pfappserver::Form::Config::FilterEngines::DNSFilter;

=head1 NAME

pfappserver::Form::Config::FilterEngines::DNSFilter -

=head1 DESCRIPTION

pfappserver::Form::Config::FilterEngines::DNSFilter

=cut

use strict;
use warnings;
use pfappserver::Form::Field::DynamicList;
use HTML::FormHandler::Moose;
use pf::constants::role qw(@ROLES);
extends 'pfappserver::Form::Config::FilterEngines';
with qw(
    pfappserver::Base::Form::Role::Help
    pfappserver::Base::Form::Role::AllowedOptions
    pfappserver::Role::Form::RolesAttribute
);

sub scopes {
    return map { { value => $_, label => $_ } } qw(registration isolation inline dnsenforcement);
}

has_field answer => (
    type => 'Text',
);

my %rcodes = (
    NOERROR  => "No Error",
    FORMERR  => "Format Error",
    SERVFAIL => "Server Failure",
    NXDOMAIN => "Non-Existent Domain",
    NOTIMP   => "Not Implemented",
    REFUSED  => "Query Refused",
    YXDOMAIN => "Name Exists when it should not",
    YXRRSET  => "RR Set Exists when it should not",
    NXRRSET  => "RR Set that should exist does not",
    NOTAUTH  => "Server Not Authoritative for zone",
    NOTAUTH  => "Not Authorized",
    NOTZONE  => "Name not contained in zone",
    BADVERS  => "Bad OPT Version",
    BADSIG   => "TSIG Signature Failure",
    BADKEY   => "Key not recognized",
    BADTIME  => "Signature out of time window",
    BADMODE  => "Bad TKEY Mode",
    BADNAME  => "Duplicate key name",
    BADALG   => "Algorithm not supported",
    BADTRUNC => "Bad Truncation",
);

my %ADDITIONAL_FIELD_OPTIONS = (
    %pfappserver::Form::Config::FilterEngines::ADDITIONAL_FIELD_OPTIONS
);

sub _additional_field_options {
    return \%ADDITIONAL_FIELD_OPTIONS;
}

sub options_field_names {
    qw(
      qname
      qclass
      qtype
      peerhost
      query
      conn.peerhost
      conn.sockport
      conn.sockhost
      conn.peerport
      time
      mac
    );
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
