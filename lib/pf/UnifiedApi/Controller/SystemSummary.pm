package pf::UnifiedApi::Controller::SystemSummary;

=head1 NAME

pf::UnifiedApi::Controller::SystemSummary -

=head1 DESCRIPTION

pf::UnifiedApi::Controller::SystemSummary

=cut

use strict;
use warnings;
use Mojo::Base 'pf::UnifiedApi::Controller::RestRoute';
use pf::db;
use pf::config::util qw(is_inline_configured);
use pf::version;
use pf::cluster;
use Fcntl qw(SEEK_SET);
use pf::UnifiedApi::Controller::Config::System;

sub get {
    my ($self) = @_;
    return $self->render(
        json => {
           readonly_mode => db_check_readonly() ? $self->json_true : $self->json_false,
           is_inline_configured => is_inline_configured() ? $self->json_true : $self->json_false,
           version => pf::version::version_get_current(),
           hostname => pf::UnifiedApi::Controller::Config::System::_get_hostname,
           uptime(),
           git_commit_id(),
           db_version => do {my $v = eval { pf::version::version_get_last_db_version() }; $v},
        }
    );

}

our $GIT_COMMIT_ID_FILE = '/usr/local/pf/conf/git_commit_id';

my $UPTIME_FH;
open ($UPTIME_FH, '<', "/proc/uptime");

=head2 uptime

uptime

=cut

sub uptime {
    if (!$UPTIME_FH) {
        return ;
    }

    seek($UPTIME_FH, 0, SEEK_SET);
    my $uptime_info = <$UPTIME_FH>;
    my ($uptime, $idle) = $uptime_info =~ /(\d+(?:\.\d+)?) ((\d+(?:\.\d+)?))/;
    return (uptime => $uptime)
}

=head2 git_commit_id

git_commit_id

=cut

sub git_commit_id {
    my ($self, $ctx, $args) = @_;
    my $id = undef;
    if ( -f $GIT_COMMIT_ID_FILE) {
        if (open(my $fh, $GIT_COMMIT_ID_FILE)) {
            {
                local $/ = undef;
                $id = <$fh>;
            }
            chomp($id);
        }
    }

    return (git_commit_id => $id);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2022 Inverse inc.

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
