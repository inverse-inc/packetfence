package pfappserver::Role::Controller::Audit;

=head1 NAME

pfappserver::Role::Controller::Audit - Role for Audit logging

=cut

=head1 DESCRIPTION

pfappserver::Role::Controller::Audit

=cut

use strict;
use warnings;

use Moose::Role;

=head2 audit_current_action

Create an audit log entry

=cut

sub audit_current_action {
    my ($self, $c, @args) = @_;
    my $action = $c->action;
    $c->model("Audit")->write_json_entry({
        user => $c->user->id,
        action => $action->name,
        context => $action->private_path,
        happened_at => scalar localtime(),
        @args,
    });
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
