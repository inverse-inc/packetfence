package pf::cmd::pf::schedule;

=head1 NAME

pf::cmd::pf::schedule add documentation

=head1 SYNOPSIS

 pfcmd schedule <view|now|add|edit|delete> [number|ip-range|ipaddress/cidr|all] [assignments]

  use nessus to scan ip(s).  IP address can be specified as IP, Start-EndIP, IP/xx Cidr format.

    examples:
      pfcmd schedule view all
      pfcmd schedule view 1
      pfcmd schedule now 128.11.23.2/24
      pfcmd schedule add 128.11.23.7/24 date="0 3 * * *"
      pfcmd schedule add 128.11.23.2/24 date="0 3 * * *"
      pfcmd schedule delete 2

=head1 DESCRIPTION

pf::cmd::pf::schedule

=cut

use strict;
use warnings;
use Readonly;
use base qw(pf::base::cmd::action_cmd);
use pf::file_paths qw($bin_dir);
use pf::log;
use pf::constants::exit_code qw($EXIT_SUCCESS $EXIT_FAILURE);

Readonly my $delimiter => '|';
Readonly my $PFCMD     => $bin_dir . "/pfcmd";
my $logger = get_logger();

=head1 METHODS

=head2 _get_cron

Get the cron object

=cut

sub _get_cron {
    require pf::schedule;
    return new pf::schedule();
}

=head2 _valid_host

Verify host

=cut

sub _valid_host {
    my ($host) = @_;
    return 0 unless $host =~ /(\d{1,3}\.){3}\d{1,3}[\/\-0-9]*/;
    return 1;
}


=head2 _parse_params

Parse parameters

=cut

sub _parse_params {
    my (@params) = @_;
    my %results;
    for my $param (@params) {
        return undef unless $param =~ /([a-zA-Z_]+) *= *(.*)$/;
        my $colname = $1;
        my $value = $2;
        return undef unless $value =~ /^(?:"([&=?()\/,0-9a-zA-Z_\*\.\-\:_\;\@\ \+\!]*)"|([\/0-9a-zA-Z_\*\.\-\:_\;\@ ]+))$/;
        $value = $2 // $1;
        $results{$colname} = $value;
    }
    if (exists $results{date} && $results{date} !~ /(\d+|\*)( (\d+|\*)){4}/) {
        return undef;
    }
    return undef if exists $results{host} && !_valid_host($results{host});
    return \%results;
}


=head2 action_now

Runs the scan

=cut

sub action_now {
    my ($self)     = @_;
    my ($hostaddr) = $self->action_args;
    $logger->trace("pcmd schedule now called for $hostaddr");

    my $host_mac = pf::ip4log::ip2mac($hostaddr);

    my $profile = pf::Connection::ProfileFactory->instantiate($host_mac);
    my @scanners = $profile->findScans($host_mac);
    my $current_scan = pop @scanners;

    require pf::scan;

    while(defined($current_scan)){
        $logger->debug("Scheduled Scan -- Current Scan Engine Is -- > $current_scan");
        pf::scan::run_scan($hostaddr,$host_mac,$current_scan);
        $current_scan = pop @scanners;
    }

    $logger->trace("leaving pfcmd schedule now $hostaddr");
    return $EXIT_SUCCESS;
}

=head2 parse_now

Parses the args for pfcmd schedule now

=cut

sub parse_now {
    my ($self, @args) = @_;
    return 0 unless @args;
    return _valid_host($args[0])
}

=head2 action_view

View the currently scheduled scans

=cut

sub action_view {
    my ($self)     = @_;
    my ($hostaddr) = $self->action_args;
    my $cron       = _get_cron();
    $cron->load_cron("pf");
    if ($hostaddr eq 'all') {
        print join($delimiter, ("id", "date", "hosts")) . "\n";
        print $cron->get_indexes();
    }
    else {
        my $cronref = $cron->get_index($hostaddr);
        if (defined($cronref)) {
            print join($delimiter, ("id", "date", "hosts")) . "\n";
            print join($delimiter, $cron->get_index($hostaddr)) . "\n";
        }
    }
    return $EXIT_SUCCESS;
}

=head2 parse_view

Parse the args for pfcmd schedule view

=cut

sub parse_view {
    my ($self, @args) = @_;
    return 0 unless $args[0] =~ /^(all|\d+)$/;
    return 1;
}

=head2 action_add

Add a new scheduled scan

=cut

sub action_add {
    my ($self) = @_;
    my $hostaddr = $self->{new_host};
    my $date = $self->{new_date};
    my $cron = _get_cron();
    $cron->load_cron("pf");
    $logger->trace("Adding scheduled scan cron entry with date: $date");
    $cron->add_index($date, "$PFCMD schedule now $hostaddr");
    $cron->write_cron("pf");
    return $EXIT_SUCCESS;
}

=head2 parse_add

Parse the args for pfcmd schedule add

=cut

sub parse_add {
    my ($self, $new_host, @args) = @_;
    #Return if there are more than two arguments
    return 0 unless @args;
    unless ( _valid_host($new_host) ) {
        $logger->trace("Invalid host");
        return 0;
    }
    my $params;
    unless (defined ( $params =  _parse_params(@args)))  {
        $logger->trace("Invalid params");
        return 0;
    }
    return 0 unless exists $params->{date};
    $self->{new_host} = $new_host;
    $self->{new_date} = $params->{date};
    return 1;
}

=head2 action_delete

Delete an existing scan object

=cut

sub action_delete {
    my ($self)     = @_;
    my ($id) = $self->action_args;
    my $cron       = _get_cron();
    $cron->load_cron("pf");
    $cron->delete_index($id);
    $cron->write_cron("pf");
    return $EXIT_SUCCESS;
}

=head2 parse_delete

Parse the args for pfcmd schedule view

=cut

sub parse_delete {
    my ($self, @args) = @_;
    return 0 unless @args == 1 && $args[0] =~ /^\d+$/;
    return 1;
}

=head2 action_edit

Edit an existing scan object

=cut

sub action_edit {
    my ($self)   = @_;
    my $id       = $self->{id};
    my $new_host = $self->{new_host};
    my $new_date = $self->{new_date};
    my $cron     = _get_cron();
    $cron->load_cron("pf");
    my ($old_date, $old_host) =
      ($cron->get_index($id))[1, 2];
    return $EXIT_FAILURE unless defined $old_date && defined $old_host;
    $new_host = $old_host unless defined $new_host;
    $new_date = $old_date unless defined $new_date;
    #$logger->info("updating schedule number $id to date=$new_date,hostaddr=$new_host");
    $cron->update_index($id, $new_date, "$PFCMD schedule now $new_host");
    $cron->write_cron("pf");
    return $EXIT_SUCCESS;
}

=head2 parse_edit

Parse the args for pfcmd schedule edit

=cut

sub parse_edit {
    my ($self, $id, @args) = @_;
    #Return if there are more than two arguments
    return 0 unless @args;
    return 0 unless $id =~ /\d+/;
    my $params;
    return 0 unless defined ( $params =  _parse_params(@args));
    return 0 unless exists $params->{date} || exists $params->{host};
    $self->{id} = $id;
    $self->{new_host} = $params->{host};
    $self->{new_date} = $params->{date};
    return 1;
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

