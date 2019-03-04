package pf::inline::accounting;

=head1 NAME

=cut

=head1 DESCRIPTION

=head1 CONFIGURATION AND ENVIRONMENT

=head2 MySQL SETUP

CREATE TABLE `inline_accounting` (
   `outbytes` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'orig_raw_pktlen',
   `inbytes` bigint unsigned NOT NULL DEFAULT '0' COMMENT 'reply_raw_pktlen',
   `ip` varchar(16) NOT NULL,
   `firstseen` DATETIME NOT NULL,
   `lastmodified` DATETIME NOT NULL,
   `status` int unsigned NOT NULL default 0, -- ACTIVE
   PRIMARY KEY (`ip`, `firstseen`),
   INDEX (`ip`)
 ) ENGINE=InnoDB;

=cut

use strict;
use warnings;

use Carp;
use pf::log;
use Readonly;

my $accounting_table = 'inline_accounting';

my $ACTIVE = 0;
my $INACTIVE = 1;
my $ANALYZED = 3;

BEGIN {
    use Exporter ();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT = qw(
        inline_accounting_update_session_for_ip
        inline_accounting_maintenance
    );
}

use pf::config qw($ACCOUNTING_POLICY_BANDWIDTH);
use pf::constants::trigger qw($TRIGGER_TYPE_ACCOUNTING);
use pf::dal::inline_accounting;
use pf::error qw(is_error is_success);
use pf::dal::node;
use pf::security_event;
use pf::config::security_event;
use pf::constants qw(
    $ZERO_DATE
);

=head1 SUBROUTINES

=over

=cut

=item inline_accounting_update_session_for_ip

inline_accounting_update_session_for_ip

=cut

sub inline_accounting_update_session_for_ip {
    my ($ip, $inbytes, $outbytes, $firstseen, $lastmodified) = @_;
    my $logger = get_logger();

    my ( $status, $iter ) = pf::dal::inline_accounting->search(
        -where => {
            status => $ACTIVE,
            ip     => $ip
        },
        -columns => [qw(firstseen)],
    );

    if ( is_error($status) ) {
        return (0);
    }

    my $active_session = $iter->next(undef);
    $iter->finish;
    if (defined($active_session)) {
        ($status, my $rows) = pf::dal::inline_accounting->update_items(
            -set => {
                inbytes      => \[ 'inbytes + ?',      $inbytes ],
                outbytes     => \[ 'outbytes + ?',     $outbytes ],
                lastmodified => \[ 'FROM_UNIXTIME(?)', $lastmodified ],
            },
            -where => {
                ip     => $ip,
                status => $ACTIVE,
            }
        );
    }
    else {
        $status = pf::dal::inline_accounting->create(
            {
                ip           => $ip,
                inbytes      => $inbytes,
                outbytes     => $outbytes,
                firstseen    => \[ 'FROM_UNIXTIME(?)', $firstseen ],
                lastmodified => \[ 'FROM_UNIXTIME(?)', $lastmodified ],
                status       => $ACTIVE,
            }
        );
    }
    return (is_success($status));
}

sub inline_accounting_maintenance {
    my $accounting_session_timeout = shift;
    my $logger = get_logger();
    my $result = 0;
    my $status;
    my $rows;

    # Check if there's at least a security_event using an accounting
    if (@BANDWIDTH_EXPIRED_SECURITY_EVENTS > 0) {
        $logger->debug("There is an accounting security_event. analyzing inline accounting data");

        # Disable AutoCommit since we perform a SELECT .. FOR UPDATE statement
        my $dbh = pf::dal->get_dbh();
        $dbh->begin_work or $logger->logdie("Can't enable database transactions: " . $dbh->errstr);

        # Extract nodes with no more bandwidth left (considering also active sessions)
        my ($status, $iter) = pf::dal::inline_accounting->search(
            -where => {
                'n.status' => $pf::node::STATUS_REGISTERED,
                'n.bandwidth_balance' => [ 0, { "<" => \'inline_accounting.outbytes + inline_accounting.inbytes' } ],
            },
            -columns => [-distinct => qw(n.mac i.ip n.bandwidth_balance), 'COALESCE((inline_accounting.outbytes+inline_accounting.inbytes),0)|bandwidth_consumed'],
            -from => [-join => 'node|n', '<=>{n.mac=i.mac}', 'ip4log|i', "=>{i.ip=inline_accounting.ip,inline_accounting.status='ACTIVE'}", 'inline_accounting'],
            -for => 'UPDATE',
        );
        if (is_success($status)) {
            while (my $row = $iter->next(undef)) {
                my ($mac, $ip, $bandwidth_balance, $bandwidth_consumed) = @{$row}{qw(mac ip bandwidth_balance bandwidth_consumed)};
                $logger->debug("Node $mac/$ip has no more bandwidth (balance $bandwidth_balance, consumed $bandwidth_consumed), triggering security_event");
                # Trigger security_event for this node
                if (security_event_trigger( { 'mac' => $mac, 'tid' => $ACCOUNTING_POLICY_BANDWIDTH, 'type' => $TRIGGER_TYPE_ACCOUNTING } )) {
                    pf::dal::inline_accounting->update_items(
                        -set => {
                            status => $INACTIVE
                        },
                        -where => {
                            status => $ACTIVE,
                            ip => $ip,
                        }
                    );
                }
            }
        }

        # Commit database transaction
        unless ($dbh->commit) {
            $logger->error("Error while committing database transaction: " . $dbh->errstr);
            $dbh->rollback or $logger->logdie("Can't rollback database transaction: " . $dbh->errstr);
        }
    }

    # Stop counters of active network sessions that have exceeded the timeout
    ($status, $rows) = pf::dal::inline_accounting->update_items(
        -set => {
            status => $INACTIVE
        },
        -where => {
            status => $ACTIVE,
            lastmodified => { "<" => \['NOW() - INTERVAL ? SECOND', $accounting_session_timeout]}
        }
    );
    if (is_error($status)) {
        $logger->error("Error stopping counters of active network sessions that have exceeded the timeout");
    } elsif ($rows > 0) {
        $logger->debug("Mark $rows session(s) as inactive after $accounting_session_timeout seconds");
    }

    # Stop counters of active network sessions that have spanned a new day
    ($status, $rows) = pf::dal::inline_accounting->update_items(
        -set => {
            status => $INACTIVE
        },
        -where => {
            -and => [\'DAY(lastmodified) != DAY(firstseen)', {status => $ACTIVE}],
        }
    );
    if (is_error($status)) {
        $logger->error("Error stopping counters of active network sessions that have exceeded the timeout");
    } elsif($rows > 0) {
        $logger->debug("Mark $rows session(s) as inactive after a day change");
    }

    # Update bandwidth balance with new inactive sessions
    my ($subsql, @subbind) =  pf::dal::inline_accounting->select(
        -from => ['inline_accounting', 'ip4log'],
        -columns => [\'SUM(inline_accounting.outbytes+inline_accounting.inbytes)'],
        -where => {
            'inline_accounting.ip' => {-ident => 'ip4log.ip'},
            'ip4log.mac' => {-ident => 'node.mac'},
            'inline_accounting.status' => $INACTIVE,
            'ip4log.end_time' => $ZERO_DATE,
        },
    );

    ($status, $rows) = pf::dal::node->update_items(
        -set => {
            bandwidth_balance => \["bandwidth_balance - COALESCE(($subsql), ?)", @subbind, 0],
        },
        -where => {
            bandwidth_balance => { ">" => 0 },
        }
    );

    if (is_error($status)) {
        $logger->error("Error updating bandwidth balance with new inactive sessions");
    } elsif ($rows > 0) {
        $logger->debug("Updated the bandwidth balance of $rows nodes");
    }

    # UPDATE inline_accounting: Mark INACTIVE entries as ANALYZED
    ($status, $rows) = pf::dal::inline_accounting->update_items(
        -set => {
            status => $ANALYZED
        },
        -where => {
            status => $INACTIVE
        }
    );
    if (is_success($status) && $rows > 0) {
        $logger->debug("Mark $rows sessions as analyzed");
    }

    return 1;
}

=back

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

# vim: set shiftwidth=4:
# vim: set ts=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
