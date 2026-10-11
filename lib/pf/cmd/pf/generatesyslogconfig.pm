package pf::cmd::pf::generatesyslogconfig;

=head1 NAME

pf::cmd::pf::generatesyslogconfig

=head1 SYNOPSIS

  pfcmd generatesyslogconfig

Generates the syslog configuration

=cut

use strict;
use warnings;

use base qw(pf::cmd);
use pf::file_paths qw($syslog_config_file $syslog_default_config_file $log_dir $rsyslog_packetfence_config_file);
use pf::IniFiles;
use Template;
use File::Slurp qw(read_file write_file);
use pf::constants::exit_code qw($EXIT_SUCCESS);
use pf::constants::syslog;


=head2 items

Create the actions and conditions for each configured service

=cut

sub items {
    my ($self) = @_;
    my @items;
    my $actions = $self->actions;
    foreach my $syslog_info (@pf::constants::syslog::SyslogInfo) {
        my $name = $syslog_info->{name};
        next unless exists $actions->{$name};
        for my $condition (@{$syslog_info->{conditions}}) {
            push @items, {actions => $actions->{$name}, condition => $condition, name => $name};
        }
    }
    return \@items;
}

our %ACTION_GENERATORS = (
    file => \&file_action,
    server => \&server_action,
);

sub actions {
    my $configfile = pf::IniFiles->new(
        -file   => $syslog_config_file,
        -import => pf::IniFiles->new(
            -file       => $syslog_default_config_file,
            -allowempty => 1
        ),
        -allowempty => 1
    );

    my %actions;

    foreach my $section ( $configfile->Sections ) {
        my $data = section_data( $configfile, $section );
        my $logs = $data->{logs};
        $logs = $pf::constants::syslog::ALL_LOGS
            if $logs eq 'ALL';
        if ( !ref $logs ) {
            $logs = [ split( /\s*,\s*/, $logs ) ];
        }
        my $type = $data->{type};
        if (!exists $ACTION_GENERATORS{$type}) {
            print "Unknown generator\n";
            next;
        }
        my $action_generator = $ACTION_GENERATORS{$type};
        foreach my $log (@$logs) {
            push @{ $actions{$log} }, $action_generator->( $data, $log );
        }
    }

    return \%actions;
}


sub file_action {
    my ($data, $log) = @_;
    return "-$log_dir/$log";
}

sub server_action {
    my ($data, $log) = @_;
    my $proto = $data->{proto} eq 'udp' ? '@' : '@@';
    return "${proto}$data->{host}:$data->{port}";
}

sub section_data {
    my ($config, $section) = @_;
    my %data;
    for my $name ($config->Parameters($section)) {
        $data{$name} = $config->val($section, $name);
    }
    $data{id} = $section;
    return \%data;
}


our $RSYSLOG_MAIN_CONFIG = '/etc/rsyslog.conf';

=head2 inputs_config

The configuration of the rsyslog inputs, written before the rest of the configuration.

imjournal keeps its position in a state file, otherwise rsyslog reads the
whole journal again (and appends it to the log files) every time it starts.
On a first start without a state file, it starts at the end of the journal.

It is configured with module() since the distributions load imuxsock that
way, which makes the legacy directives ($SystemLogRateLimitInterval, ...)
invalid. When the main configuration already loads imjournal (e.g. EL), it
is left as is.

=cut

sub inputs_config {
    return '' if main_config_loads_imjournal();
    return qq{module(load="imjournal" StateFile="imjournal.state" IgnorePreviousMessages="on" Ratelimit.Interval="0" Ratelimit.Burst="0")\n};
}

=head2 main_config_loads_imjournal

Whether the main rsyslog configuration loads imjournal

=cut

sub main_config_loads_imjournal {
    my $config = eval { read_file($RSYSLOG_MAIN_CONFIG) } // '';
    return $config =~ /^\s*(?:module\s*\(\s*load\s*=\s*"imjournal"|\$ModLoad\s+imjournal\b)/m ? 1 : 0;
}

=head2 remove_legacy_inputs_config

Remove the legacy input directives of the templates of previous versions, replaced by inputs_config

=cut

sub remove_legacy_inputs_config {
    my ($config) = @_;
    $config =~ s/^[ \t]*\$(?:ModLoad[ \t]+(?:imuxsock|imjournal)|SystemLogRateLimit(?:Interval|Burst)|imjournalRatelimit(?:Interval|Burst))\b.*\n//mg;
    return $config;
}

sub _run {
    my ($self) = @_;
    my $template = "/usr/local/pf/conf/rsyslog.conf.tt";
    my $tt = Template->new(ABSOLUTE => 1);
    my $output = '';
    $tt->process($template, {items => $self->items}, \$output) || die $tt->error();
    write_file($rsyslog_packetfence_config_file, inputs_config() . remove_legacy_inputs_config($output));
    return $EXIT_SUCCESS; 
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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
