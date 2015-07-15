package captiveportal::Controller::Authenticate;
use Moose;
use pf::authentication;
use pf::person;

BEGIN { extends 'captiveportal::PacketFence::Controller::Authenticate'; }

=head2 checkIfChainedAuth

Checked to see if source that was authenticated with is chained

=cut

sub checkIfChainedAuth : Private {
    my ($self, $c) = @_;
    my $source_id = $c->session->{source_id};
    my $source = getAuthenticationSource($source_id);
    #if not chained then leave
    return unless $source && $source->type eq 'Chained';
    $c->session->{chained_source} = $source_id;
    my $pid = $c->session->{"username"};
    if($pid) {
        my $person = person_view($pid);
        if($person) {
            my  $role = $person->{category};
            if ($role && $role ne 'default') {
               $c->detach('continue_chained_auth');
            }
        }
    }
    my $chainedSource = $source->getChainedAuthenticationSourceObject();
    if( $chainedSource && $self->isGuestSigned($c,$chainedSource)) {
        $self->setAllowedGuestModes($c,$chainedSource);
        $c->detach(Signup => 'showSelfRegistrationPage');
    }
    elsif ($chainedSource->class eq 'billing') {
        $c->detach(Billing => 'index');
    }
}

=head1 NAME

captiveportal::Controller::Root - Root Controller for captiveportal

=head1 DESCRIPTION

[enter your description here]

=cut

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
