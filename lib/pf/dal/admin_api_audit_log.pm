package pf::dal::admin_api_audit_log;

=head1 NAME

pf::dal::admin_api_audit_log - pf::dal module to override for the table admin_api_audit_log

=cut

=head1 DESCRIPTION

pf::dal::admin_api_audit_log

pf::dal implementation for the table admin_api_audit_log

=cut

use strict;
use warnings;

use base qw(pf::dal::_admin_api_audit_log);
use pf::StatsD::Timer;

sub cleanup {
    my $timer = pf::StatsD::Timer->new( { sample_rate => 0.2 } );
    my ($class, $expire_seconds, $batch, $time_limit) = @_;
    my $logger = $class->logger;
    $logger->debug( sub { "calling admin_api_audit_log->cleanup with time=$expire_seconds batch=$batch timelimit=$time_limit"; });

    if ( $expire_seconds eq "0" ) {
        $logger->debug("Not deleting because the window is 0");
        return;
    }
    my $now        = pf::dal->now();
    my %search = (
        -where => {
            created_at => {
                "<" => \[ 'DATE_SUB(?, INTERVAL ? SECOND)', $now, $expire_seconds ]
            },
        },
        -limit => $batch,
        -no_auto_tenant_id => 1,
    );

    $class->batch_remove(\%search, $time_limit);
    return;
}
 
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
