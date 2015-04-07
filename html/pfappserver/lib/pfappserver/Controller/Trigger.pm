package pfappserver::Controller::Trigger;

=head1 NAME

pfappserver::Controller::Trigger - Catalyst Controller

=head1 DESCRIPTION

=cut

use Moose;
BEGIN { extends 'pfappserver::Base::Controller'; }

use pf::factory::triggerParser;


=head1 METHODS

=cut

sub search : Local : Args(2) {
    my ($self, $c, $trigger, $tid) = @_;
    $c->stash->{current_view} = 'JSON';
    my $results;
    my $tp = pf::factory::triggerParser->new($trigger);
    $c->stash->{items} = $tp->search($tid);
}

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
