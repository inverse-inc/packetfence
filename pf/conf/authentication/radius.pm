package authentication::radius;

=head1 NAME

authentication::radius

=head1 SYNOPSYS

  return (1,0) for successfull authentication
  return (0,2) for inability to check credentials
  return (0,1) for wrong login/password

=cut

use strict;
use warnings;

BEGIN {
 use Exporter ();
 our (@ISA, @EXPORT);
 @ISA    = qw(Exporter);
 @EXPORT = qw(authenticate);
}

use Authen::Radius;

my $RadiusServer = 'localhost';
my $RadiusSecret = 'testing123';

sub authenticate {
 my ($username, $password) = @_;
 my $radcheck;
 $radcheck = new Authen::Radius(
    Host => $RadiusServer, 
    Secret => $RadiusSecret);
 if ($radcheck->check_pwd($username, $password)) {
     return (1,0);
 } else {
     return (0,1);
 }
}

=head1 AUTHOR

Maikel van der roest <mvdroest@utelisys.com>

=head1 COPYRIGHT

Copyright (C) 2008 Utelisys Communications B.V.

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

