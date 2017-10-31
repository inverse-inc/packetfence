package pf::cmd::pf::tenant;

=head1 NAME

pf::cmd::pf::tenant -

=cut

=head1 SYNOPSIS

 pfcmd tenant <add> name 

=head1 DESCRIPTION

pf::cmd::pf::tenant

=cut

use strict;
use warnings;
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);
use pf::constants qw($TRUE $FALSE);
use base qw(pf::base::cmd::action_cmd);
use pf::tenant qw(tenant_add);
 
=head2 parse_add

parse_add

=cut

sub parse_add {
    my ($self, $name, @args) = @_;
    unless (defined $name) {
        print STDERR "Must provide a tenant name\n";
        return $FALSE;
    }
    my %fields = (name => $name);
    $self->{fields} = \%fields;
    return $TRUE;
}

=head2 action_add

action_add

=cut

sub action_add {
    my ($self) = @_;
    my $fields = $self->{fields};
    my $results = tenant_add($fields);
    unless ($results) {
        return $EXIT_FAILURE;
    }
    return $EXIT_SUCCESS;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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

