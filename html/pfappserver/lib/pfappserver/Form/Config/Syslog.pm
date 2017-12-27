package pfappserver::Form::Config::Syslog;

=head1 NAME

pfappserver::Form::Config::Syslog - Web form for an admin role

=head1 DESCRIPTION

Form definition to create or update an admin role

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Base::Form';
with 'pfappserver::Base::Form::Role::Help';

use pf::log;

our @logs = qw(
  collectd fingerbank httpd.aaa.access
  httpd.aaa.error httpd.admin httpd.admin.access
  httpd.admin.catalyst httpd.admin.error httpd.collector
  httpd.collector.error httpd.graphite.access httpd.graphite.error
  httpd.parking.access httpd.parking.error httpd.portal.access
  httpd.portal.catalyst httpd.portal.error httpd.proxy.access
  httpd.proxy.error httpd.webservices.access httpd.webservices.error
  packetfence pfbandwidthd pfconfig
  pfdetect pfdhcplistener pfdns
  pffilter pfmon radius
  radius-acct radius-cli radius-eduroam
  radius-load_balancer
  redis_cache redis_ntlm_cache redis_queue
);

## Definition
has_field 'id' =>
  (
   type => 'Text',
   label => 'Syslog Name',
   required => 1,
   messages => { required => 'Please specify the name of the syslog entry' },
  );
has_field 'logs' =>
  (
   type => 'Select',
   multiple => 1,
   label => 'Logs',
   options_method => \&options_logs,
   default_method => sub {[ @logs] },
   element_class => [qw(chzn-select input-xxlarge)],
   element_attr => {'data-placeholder' => 'Click to add a log'},
   tags => { after_element => \&help,
             help => 'Logs' },
  );
has_block  definition =>
  (
    render_list => [qw(logs)],
  );

sub options_logs {
    return map { { label => $_, value => $_ } } @logs;
}

=head1 COPYRIGHT

Copyright (C) 2005-2015 Inverse inc.

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
