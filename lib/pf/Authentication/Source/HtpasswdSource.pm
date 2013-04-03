package pf::Authentication::Source::HtpasswdSource;

=head1 NAME

pf::Authentication::Source::HtpasswdSource

=head1 DESCRIPTION

=cut

use pf::config qw($TRUE $FALSE);
use pf::Authentication::constants;
use pf::Authentication::Source;

use Apache::Htpasswd;

use Moose;
extends 'pf::Authentication::Source';

has '+type' => (default => 'Htpasswd');
has 'path' => (isa => 'Str', is => 'rw', required => 1);

sub available_attributes {
    my $self = shift;

    my $super_attributes = $self->SUPER::available_attributes; 
    my $own_attributes = [{ value => 'username', type => $Conditions::SUBSTRING }];

    return [@$super_attributes, @$own_attributes];
}

=item authenticate

=cut
sub authenticate {
    my ( $self, $username, $password ) = @_;
  
    my $logger = Log::Log4perl->get_logger('pf::authentication');
    my $password_file = $self->{'path'};
  
    if (! -r $password_file) {
        $logger->error("unable to read password file '$password_file'");
        return ($FALSE, 'Unable to validate credentials at the moment');
    }
  
    my $htpasswd = new Apache::Htpasswd({ passwdFile => $password_file, ReadOnly   => 1});
    if ( (!defined($htpasswd->htCheckPassword($username, $password))) 
         or ($htpasswd->htCheckPassword($username, $password) == 0) ) {
    
        return ($FALSE, 'Invalid login or password');
    }

    return ($TRUE, 'Successful authentication using htpasswd file.');
}

=item match

=cut
sub match_in_subclass {
    
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    
    my $logger = Log::Log4perl->get_logger( __PACKAGE__ );
    $logger->info("Matching rules in htpasswd file.");

    # Let's match the htpasswd conditions alltogether. Normally, we
    # should only have a condition based on the username attribute.
    foreach my $condition (@{ $own_conditions }) {
        if ($condition->{'attribute'} eq "username") {
            # Let's check if our matching username is found in our htpasswd file
            my $password_file = $self->{'path'};
            if (-r $password_file) {
                my $htpasswd = new Apache::Htpasswd({ passwdFile => $password_file, ReadOnly   => 1});
                if ( defined($htpasswd->fetchPass($params->{'username'})) ) {
                    # Username is defined in the htpasswd file
                    # Now let's see if the condition actually matches
                    if ( $condition->matches("username", $params->{'username'}) ) {
                        push(@{ $matching_conditions }, $condition);
                    }
                }
            }
        }
    }

    return undef;
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
