package pf::pfmon::task::email_expiring_devices;

=head1 NAME

pf::pfmon::task::email_expiring_devices - class for pfmon task cluster check

=cut

=head1 DESCRIPTION

pf::pfmon::task::email_expiring_devices

=cut

use strict;
use warnings;
use pf::CHI;
use pf::log;
use Moose;
use pf::constants;
use pf::log;
use pf::util;
extends qw(pf::pfmon::task);

has 'window' => ( is => 'rw', default => "1W" );
has 'email_every' => ( is => 'rw', default => "1D" );
has 'email_on_all_changes' => ( is => 'rw', default => "enabled" );

=head2 run

=cut

sub run {
    my ($self) = @_;
    my $logger = get_logger;
    my %expiring;

    my $cache = pf::CHI->new(namespace => "email_expiring_devices");
    
    my $nodes = pf::dal::node->search(
        -where => {
            unregdate => [ -and => {
                "<" => \[ 'DATE_ADD(NOW(), INTERVAL ? SECOND)', $self->window ],
                "!=" => $ZERO_DATE,
            }],
        },
    );

    $nodes = $nodes->all(undef);
    for my $node (@$nodes) {
        my $pid = $node->{pid};
        $expiring{$pid} //= {};
        $expiring{$pid}{$node->{mac}} = $node;
    }
    
    while(my ($pid, $pid_nodes) = each(%expiring)) {
        my $macs_list = join(",", keys(%$pid_nodes));
        $logger->info("Emailing $pid for his devices that are expiring soon (".$macs_list.")");
        my $key = isenabled($self->email_on_all_changes) ? "$pid-$macs_list" : $pid;
        $cache->compute($key, sub {
            my $person = pf::dal::person->find({pid => $pid});
            if($person->{email}) {
                #TODO: actually send out the email
                print "Sending email to $person->{email} \n";
            }
            else {
                $logger->warn("No email address for $pid, cannot send expiring devices information");
            }
        }, { expires_in => $self->email_every });
    }
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
