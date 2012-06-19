package pf::web::wispr;

=head1 NAME

pf::web::wispr - Captive Portal Wireless ISP Roaming support

=cut

=head1 DESCRIPTION

WISPR is a draft spec that improves the workflow to connect to a web-based captive portal.
See L<http://www.acmewisp.com/WISPr_V1.0.pdf> for details about the spec.

=head1 STATUS

At this moment, PacketFence supports only the first redirect portion of the WISPR spec.

=head1 CONFIGURATION AND ENVIRONMENT

Templates are located in F<html/captive-portal/wispr/>

=cut

use strict;
use warnings;

use Readonly;
use Template;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    # No export to force users to use full package name and allowing pf::web::custom to redefine us
    @EXPORT = qw();
}

use pf::config;

Readonly our $WISPR_TEMPLATE_DIR => "$install_dir/html/captive-portal/wispr";

=head1 SUBROUTINES

=over

=item generate_redirect

Generates the proper XML message to redirect a WISPR client to the Captive Portal

Tested on iPod touch 4.2.1

=cut
sub generate_redirect {
    my ( $cgi, $session ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $vars = { 
        'login_url' => "https://".$Config{'general'}{'hostname'}.".".$Config{'general'}{'domain'}."/captive-portal",
    };

    print $cgi->header( 'text/html' );
    my $template = Template->new( { INCLUDE_PATH => [$WISPR_TEMPLATE_DIR], } );
    $template->process( "redirect.tt", $vars ) || $logger->error($template->error());;
    exit;
}


=back

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2011 Inverse inc.

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
