package captiveportal::View::MobileConfig;

use strict;
use warnings;
use Moose;
extends 'captiveportal::View::HTML';
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

captiveportal::View::MobileConfig - TT View for captiveportal

=head1 DESCRIPTION

TT View for captiveportal.

=head1 SEE ALSO

L<captiveportal>

=head1 AUTHOR

root

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
