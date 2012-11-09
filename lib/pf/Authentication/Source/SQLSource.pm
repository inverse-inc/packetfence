package pf::Authentication::Source::SQLSource;

=head1 NAME

pf::Authentication::Source::SQLSource

=head1 DESCRIPTION

=cut

use pf::config qw($TRUE $FALSE);
use pf::temporary_password;
use pf::Authentication::constants;
use pf::Authentication::Source;

use Moose;
extends 'pf::Authentication::Source';

has '+type' => ( default => 'SQL' );

sub available_attributes {
  my $self = shift;

  my $super_attributes = $self->SUPER::available_attributes; 
  my $own_attributes = [{ value => "username", type => $Conditions::STRING }];

  return [@$super_attributes, @$own_attributes];
}

=item authenticate_using_sql

=cut
sub authenticate {  
   my ( $self, $username, $password ) = @_;
   
   my $logger = Log::Log4perl->get_logger('pf::authentication');
   my $result = pf::temporary_password::validate_password($username, $password);
   
   if ($result == $pf::temporary_password::AUTH_SUCCESS) {
     return ($TRUE, 'Successful authentication using SQL.');
   }
   
   $logger->error("Unable to perform SQL authentication.");
   
   return ($FALSE, 'Unable to authenticate successfully using SQL.');
 }

=back

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
