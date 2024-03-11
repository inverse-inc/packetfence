package pfappserver::Form::Config::EventLogger::syslog;

=head1 NAME

pfappserver::Form::Config::EventLogger::syslog -

=head1 DESCRIPTION

pfappserver::Form::Config::EventLogger::syslog

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;

extends 'pfappserver::Form::Config::EventLogger';
with 'pfappserver::Base::Form::Role::Help';


has_field facility => (
    type    => 'Select',
    options => [
        map { { label => $_, value => $_ } }
        qw(
          auth
          authpriv
          console
          cron
          daemon
          ftp
          kernel
          local0
          local1
          local2
          local3
          local4
          local5
          local6
          local7
          lpr
          mail
          news
          ntp
          security
          solaris-cron
          syslog
          user
          uucp
          )
    ],
    required => 1,
);

has_field priority => (
    type    => 'Select',
    options => [
        map { { label => $_, value => $_ } }
            qw(emergency alert critical error warning notice informational debug)
    ],
    default => 'notice',
    required => 1,
);

has_field port => (
    type => 'Port',
    default => 514,
    required => 1,
);

has_field host => (
    type => 'Text',
    required => 1,
);

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

