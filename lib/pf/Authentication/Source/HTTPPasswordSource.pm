package pf::Authentication::Source::HTTPPasswordSource;

=head1 NAME

pf::Authentication::Source::HTTPPassswordSource

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
    my $own_attributes = [{ value => 'username', type => $Conditions::STRING }];

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
sub match {
    my ( $self, $params ) = @_;
    my $common_attributes = $self->SUPER::common_attributes();

    my $logger = Log::Log4perl->get_logger('pf::authentication');
    $logger->info("Matching rules in htpasswd file.");

    my @matching_rules = ();

    foreach my $rule ( @{$self->{'rules'}} ) {
        my @matching_conditions = ();
        my @own_conditions = ();
        if (!defined $rule->{'conditions'} || scalar @{$rule->{'conditions'}} == 0) {
            push(@matching_rules, $rule);
            goto done;
        }

        foreach my $condition ( @{$rule->{'conditions'}} ) {
            if (grep {$_->{value} eq $condition->attribute } @$common_attributes) {
                my $r = $self->SUPER::match_condition($condition, $params);
	
                if ($r == 1) {
                    push(@matching_conditions, $condition);
                }
            } elsif (grep {$_->{value} eq $condition->attribute } @{$self->available_attributes()}) {
                push(@own_conditions, $condition);
            }
        }                       # foreach my $condition (...)
    
        # We're done looping, let's match the htpasswd conditions alltogether. Normally, we
        # should only have a condition based on the username attribute.
        foreach my $condition (@own_conditions) {
            if ($condition->{'attribute'} eq "username") {
                # Let's check if our matching username is found in our htpasswd file
                my $password_file = $self->{'path'};
                if (-r $password_file) {
                    
                    my $htpasswd = new Apache::Htpasswd({ passwdFile => $password_file, ReadOnly   => 1});

                    if ( defined($htpasswd->fetchPass($params->{'username'})) ) {
                        
                        # Now let's see if the condition actually matches
                        if ( $condition->matches("username", $params->{'username'}) ) {
                            push(@matching_conditions, $condition);
                        }
                    }
                }
            }
        }
  
        # We compare the matched conditions with how many we had
        if ($rule->match eq pf::Authentication::Rule->ANY &&
            scalar @matching_conditions > 0) {
            push(@matching_rules, $rule);
        } elsif ($rule->match eq pf::Authentication::Rule->ALL &&
                 scalar @matching_conditions == scalar @{$rule->{'conditions'}}) {
            push(@matching_rules, $rule);
        }

        # For now, we return the first matching rule. We might change this in the future
        # so let's keep the @matching_rules array for now.
        done:
        if (scalar @matching_rules == 1) {
            $logger->info("Matched rule ($rule->{'description'}), returning actions.");
            return $rule->{'actions'};
        }
	
    }                     # foreach my $rule ( @{$self->{'rules'}} ) {

    return undef;
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
