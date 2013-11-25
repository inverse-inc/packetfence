package captive::portal::View::MobileConfig;

use strict;
use warnings;
use Moose;
extends 'captive::portal::View::HTML';
use pf::file_paths;

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.xml',
    render_die         => 1,
    INCLUDE_PATH       => ["$install_dir/html/captive-portal/templates"]
);

after process => sub {
    my ( $self, $c ) = @_;
    my $headers = $c->response->headers;
    $headers->content_type('application/x-apple-aspen-config; chatset=utf-8');
    $headers->header( 'Content-Disposition',
        'attachment; filename="wireless-profile.mobileconfig"' );
};

=head1 NAME

captive::portal::View::MobileConfig - TT View for captive::portal

=head1 DESCRIPTION

TT View for captive::portal.

=head1 SEE ALSO

L<captive::portal>

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
