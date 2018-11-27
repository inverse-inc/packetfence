package pf::web::openvashook;

=head1 NAME

pf::web::billinghook

=cut

=head1 DESCRIPTION

pf::web::billinghook

=cut

use strict;
use warnings;
use Apache2::Const -compile => qw(OK HTTP_OK SERVER_ERROR);
use Apache2::RequestIO();
use Apache2::RequestRec();
use pf::log;
use HTTP::Status qw(:constants);
use pf::scan::openvas;
use pf::factory::scan;

my $logger = get_logger();

sub handler {
    my ($r) = @_;
    my $args = $r->args();
    if($args =~ /task=(.+)/) {
        my $task = $1;
        get_logger->info("Will analyze OpenVAS report for task $task");
        my $info = pf::scan::openvas->getScanInfo($task);
        
        unless($info) {
            get_logger->error("Cannot find scan info for task $task");
            $r->status(HTTP_INTERNAL_SERVER_ERROR);
            return Apache2::Const::OK;
        }

        my $scan = pf::factory::scan->new($info->{scan_id});
        $scan->processReport($task);

        $r->status(HTTP_OK);
        return Apache2::Const::OK;
    }
    else {
        get_logger->error("Unable to parse task name from args: $args");
        $r->status(HTTP_INTERNAL_SERVER_ERROR);
        return Apache2::Const::OK;
    }
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
