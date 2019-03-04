package pf::Authentication::Source::ADSource;

=head1 NAME

pf::Authentication::Source::ADSource

=head1 DESCRIPTION

=cut

use pf::Authentication::constants;
use pf::constants::authentication::messages;
use pf::Authentication::Source::LDAPSource;
use pf::constants;

use Moose;
extends 'pf::Authentication::Source::LDAPSource';

has '+type' => ( default => 'AD' );

=head2 ldap_attributes

Add ldap search attributes for Active Directory
memberOf:1.2.840.113556.1.4.1941: attribute is for nested group, see https://msdn.microsoft.com/en-us/library/aa746475%28v=vs.85%29.aspx

=cut

sub ldap_attributes {
  my ($self) = @_;
  return (
    $self->SUPER::ldap_attributes,
     { value => "sAMAccountName", type => $Conditions::SUBSTRING },
     { value => "sAMAccountType", type => $Conditions::SUBSTRING },
     { value => "userAccountControl", type => $Conditions::SUBSTRING },
     { value => "memberOf:1.2.840.113556.1.4.1941:", type => $Conditions::SUBSTRING },
    );
}

=head2 findAtttributeFrom

Get an attribute of an object given another of its attribute
If more than one entry has the same attribute/value in the search, this will fail and return $FALSE

=cut

sub findAtttributeFrom {
    my ($self, $from_attribute, $from_value, $to_attribute) = @_;

    my ($connection, $LDAPServer, $LDAPServerPort ) = $self->_connect();

    if (!defined($connection)) {
        return ($FALSE, "Error communicating with the LDAP server");
    }

    my $result = $connection->search(
        base => $self->{basedn}, 
        filter => "($from_attribute=$from_value)", 
        attrs => [$to_attribute],
    );

    return ($FALSE, "Cannot find $to_attribute of object ".$from_value) unless($result->count > 0);
    return ($FALSE, "Too many entries matching $from_attribute=$from_value") if($result->count > 1);

    my $to_value = $result->entry(0)->get_value($to_attribute);

    return $to_value;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
