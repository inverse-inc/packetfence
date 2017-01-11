package pfappserver::Form::Config::Pfmon::traplog_cleanup;

=head1 NAME

pfappserver::Form::Config::Pfmon::traplog_cleanup - Web form for traplog_cleanup pfmon task

=head1 DESCRIPTION

=cut

use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Pfmon';
use pf::config::pfmon qw(%ConfigPfmonDefault);

has_field 'window' => ( 
    type => 'Duration', 
);

=head2 default_window

default value of window

=cut

sub default_window {
    return $ConfigPfmonDefault{traplog_cleanup}{window};
};

=head2 default_interval

default value of interval

=cut

sub default_interval {
    return $ConfigPfmonDefault{traplog_cleanup}{interval};
}

=head2 default_enabled

default value of enabled

=cut

sub default_enabled {
    return $ConfigPfmonDefault{traplog_cleanup}{enabled};
}

=head2 default_type

default value of type

=cut

sub default_type {
    return "traplog_cleanup";
}

has_block  definition =>
  (
    render_list => [qw(type enabled interval window)],
  );


=head1 COPYRIGHT

Copyright (C) 2005-2017 Inverse inc.

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
