package pfappserver::Model::Node::Tab::Violations;

=head1 NAME

pfappserver::Model::Node::Tab::Violations -

=cut

=head1 DESCRIPTION

pfappserver::Model::Node::Tab::Violations

=cut

use strict;
use warnings;
use pf::config qw(%Config);
use pf::error qw(is_error is_success);
use pf::violation;
use base qw(pfappserver::Base::Model::Node::Tab);

=head2 process_tab

Process Tab

=cut

sub process_view {
    my ($self, $c, @args) = @_;
    my $mac = $c->stash->{mac};
    our @items;
    eval {
        @items = violation_view_desc($mac);
        for my $violation (@items) {
            if ($violation->{release_date} eq '0000-00-00 00:00:00' ) {
                $violation->{release_date} = '';
            }
        }
    };
    if ($@) {
        my $status_msg = "Can't fetch violations from database.";
        $c->log->error($status_msg);
        return ($STATUS::INTERNAL_SERVER_ERROR, { status_msg => $status_msg });
    }
    my (undef, $result) = $c->model('Config::Violations')->readAll();
    my @violations = grep { $_->{id} ne 'defaults' } @$result; # remove defaults
    return ($STATUS::OK, { items => \@items, violations => \@violations });
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
