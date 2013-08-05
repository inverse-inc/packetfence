package pfappserver::View::HTML;

use strict;
use warnings;
use pf::file_paths;
use pf::admin_roles;

use base 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    PRE_PROCESS => 'macros.inc',
    FILTERS => {
        css => \&css_filter,
        js => \&js_filter,
    },
    render_die => 1,
    expose_methods => [qw(has_role)],
    COMPILE_DIR => $tt_compile_cache_dir
);

=head1 NAME

pfappserver::View::HTML - TT View for pfappserver

=head1 DESCRIPTION

TT View for pfappserver.

=head1 SEE ALSO

L<pfappserver>

=cut

=head2 css_filter

=cut

sub css_filter {
    my $string = shift;
    $string =~ s/[^_a-zA-Z0-9]/_/g;

    return $string;
}

=head2 js_filter

=cut

sub js_filter {
    my $string = shift;
    $string =~ s/(\\|'|"|\/)/\\$1/g;

    return $string;
}

=head2 has_role

=cut

sub has_role {
    my ($self, $c, $role) = @_;
    return admin_has_role($c->user,$role);
}

=head1 COPYRIGHT

Copyright (C) 2012-2013 Inverse inc.

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
