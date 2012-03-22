#!/usr/bin/perl
=head1 NAME

email_activation.cgi - handles email activation links

=cut
use strict;
use warnings;

use lib "/usr/local/pf/lib";

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use CGI::Session;
use Log::Log4perl;
use POSIX;

use pf::email_activation;
use pf::node;
use pf::web;
use pf::web::guest 1.10;
use pf::web::custom;

Log::Log4perl->init("$conf_dir/log.conf");
my $logger = Log::Log4perl->get_logger('email_activation.cgi');
Log::Log4perl::MDC->put('proc', 'email_activation.cgi');
Log::Log4perl::MDC->put('tid', 0);

my $cgi = new CGI;
$cgi->charset("UTF-8");
my $session = new CGI::Session(undef, $cgi, {Directory=>'/tmp'});

if (defined($cgi->url_param('code'))) {

    # validate code
    my $activation_record = pf::email_activation::validate_code($cgi->url_param('code'));
    if (!defined($activation_record) || ref($activation_record) ne 'HASH' || !defined($activation_record->{'mac'})) {

        pf::web::generate_error_page($cgi, $session, "The activation code provided is invalid. "
            . "Reasons could be: it never existed, it was already used or has expired."
        );
        exit(0);
    }

    my $node_mac = $activation_record->{'mac'};
    # expiration according to config
    my $access_duration = $Config{'guests_self_registration'}{'access_duration'};
    my $expiration = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime( time + $access_duration ));
    my $category = $Config{'guests_self_registration'}{'category'};

    # change the unregdate of the node associated with the submitted code
    node_modify($node_mac, ('unregdate' => $expiration, 'status' => 'reg', 'category' => $category));

    # send to success page
    pf::web::guest::generate_activation_confirmation_page($cgi, $session, $expiration);

} else {

    $logger->info("User has nothing to do here, redirecting to ".$Config{'trapping'}{'redirecturl'});
    print $cgi->redirect($Config{'trapping'}{'redirecturl'});

}

=head1 AUTHOR

Olivier Bilodeau <obilodeau@inverse.ca>
        
=head1 COPYRIGHT
        
Copyright (C) 2010-2012 Inverse inc.
    
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

