package captiveportal::PacketFence::View::HTML;

use strict;
use warnings;
use Locale::gettext qw(gettext ngettext);
use Moose;
use utf8;
extends 'Catalyst::View';


=head2 process

Process the view using the informations in the stash

=cut

sub process {
    my ($self, $c) = @_;
    $c->stash->{application}->render($c->stash->{template}, $c->stash);
    $c->response->body($c->stash->{application}->template_output);
}

=head1 NAME

captiveportal::View::HTML - TT View for captiveportal

=head1 DESCRIPTION

TT View for captiveportal.

=head1 SEE ALSO

L<captiveportal>

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

1;
