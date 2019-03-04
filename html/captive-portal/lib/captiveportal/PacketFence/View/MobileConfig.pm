package captiveportal::PacketFence::View::MobileConfig;

use strict;
use warnings;
use Moose;
extends 'captiveportal::View::HTML';
use pf::file_paths qw($install_dir);

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.xml',
    render_die         => 1,
    INCLUDE_PATH       => ["$install_dir/html/captive-portal/templates"]
);

after process => sub {
    my ($self, $c) = @_;
    my $headers = $c->response->headers;
    my $filename = $c->stash->{filename} || 'wireless-profile.mobileconfig';
    $headers->content_type('application/x-apple-aspen-config; chatset=utf-8');
    $headers->header('Content-Disposition', "attachment; filename=\"$filename\"");
    my $provisioner = $c->stash->{provisioner};
    if ($provisioner->can_sign_profile) {
        $c->response->body($provisioner->sign_profile($c->response->body));
    }

    #Logging the content body
    $c->log->trace(sub {$c->response->body});
};

=head1 NAME

captiveportal::View::MobileConfig - TT View for captiveportal

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
