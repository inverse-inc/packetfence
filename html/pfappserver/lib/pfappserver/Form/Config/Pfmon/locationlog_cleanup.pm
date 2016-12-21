package pfappserver::Form::Config::Pfmon::locationlog_cleanup;

=head1 NAME

pfappserver::Form::Config::Pfmon::locationlog_cleanup - Web form for locationlog_cleanup pfmon task

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
has_field 'window' => ( 
    type => 'Duration', 
);

=head2 default_batch

default value of batch

=cut

sub default_batch {
    return $ConfigPfmonDefault{locationlog_cleanup}{batch};
};
=head2 default_timeout

default value of timeout

=cut

sub default_timeout {
    return $ConfigPfmonDefault{locationlog_cleanup}{timeout};
};
=head2 default_window

default value of window

=cut

sub default_window {
    return $ConfigPfmonDefault{locationlog_cleanup}{window};
};

=head2 default_interval

default value of interval

=cut

sub default_interval {
    return $ConfigPfmonDefault{locationlog_cleanup}{interval};
}

=head2 default_enabled

default value of enabled

=cut

sub default_enabled {
    return $ConfigPfmonDefault{locationlog_cleanup}{enabled};
}

=head2 default_type

default value of type

=cut

sub default_type {
    return "locationlog_cleanup";
}

has_block  definition =>
  (
    render_list => [qw(type enabled interval batch timeout window)],
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
