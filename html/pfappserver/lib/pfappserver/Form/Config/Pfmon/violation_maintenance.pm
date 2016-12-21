package pfappserver::Form::Config::Pfmon::violation_maintenance;

=head1 NAME

pfappserver::Form::Config::Pfmon::violation_maintenance - Web form for violation_maintenance pfmon task

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Pfmon';
use pf::config::pfmon qw(%ConfigPfmonDefault);

has_field 'batch' => ( 
    type => 'PosInteger', 
);
has_field 'timeout' => ( 
    type => 'Duration', 
);

=head2 default_batch

default value of batch

=cut

sub default_batch {
    return $ConfigPfmonDefault{violation_maintenance}{batch};
};
=head2 default_timeout

default value of timeout

=cut

sub default_timeout {
    return $ConfigPfmonDefault{violation_maintenance}{timeout};
};

=head2 default_interval

default value of interval

=cut

sub default_interval {
    return $ConfigPfmonDefault{violation_maintenance}{interval};
}

=head2 default_enabled

default value of enabled

=cut

sub default_enabled {
    return $ConfigPfmonDefault{violation_maintenance}{enabled};
}

=head2 default_type

default value of type

=cut

sub default_type {
    return "violation_maintenance";
}

has_block  definition =>
  (
    render_list => [qw(type enabled interval batch timeout)],
  );


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

__PACKAGE__->meta->make_immutable;

1;
