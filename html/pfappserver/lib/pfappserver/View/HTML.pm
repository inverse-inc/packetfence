package pfappserver::View::HTML;

use strict;
use warnings;
use pf::admin_roles;

use base 'Catalyst::View::TT';
use Template::AutoFilter;
use Template::AutoFilter::Parser;

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    PRE_PROCESS => 'macros.inc',
    FILTERS => {
        css => \&css_filter,
        css_escape => \&css_escape_filter,
        js => \&js_filter,
        none => sub { $_[0] },
    },
    CLASS => 'Template::AutoFilter',
    render_die => 1,
    expose_methods => [qw(can_access can_access_any can_access_group_any)],
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

=head2 css_escape_filter

css_escape_filter

=cut

sub css_escape_filter {
    my ($string) = @_;
    $string =~ s/\\/\\\\/g;
    $string =~ s/([!"#\$\%\&'\(\)\*\+,\.\/:;<=>?@\[\]^`\{\|\}\\~-])/\\$1/g;
    return $string;
}

=head2 js_filter

=cut

sub js_filter {
    my $string = shift;
    $string =~ s/(\\|'|"|\/)/\\$1/g;

    return $string;
}

=head2 can_access

=cut

sub can_access {
    my ($self, $c, @actions) = @_;
    my $roles = [];
    $roles = [$c->user->roles] if $c->user_exists;
    return admin_can($roles,@actions);
}

=head2 can_access_any

=cut

sub can_access_any {
    my ($self, $c, @actions) = @_;
    my $roles = [];
    $roles = [$c->user->roles] if $c->user_exists;
    return admin_can_do_any($roles,@actions);
}

=head2 can_access_group_any

=cut

sub can_access_group_any {
    my ($self, $c, $group) = @_;
    my $roles = [];
    $roles = [$c->user->roles] if $c->user_exists;
    return admin_can_do_any_in_group($roles,$group);
}

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
