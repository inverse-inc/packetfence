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
    return "-${proto}$data->{host}:$data->{port}";
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


sub _run {
    my ($self) = @_;
    my $template = "/usr/local/pf/conf/rsyslog.conf.tt";
    my $tt = Template->new(ABSOLUTE => 1);
    $tt->process($template, {items => $self->items}, $rsyslog_packetfence_config_file) || die $tt->error();
    return $EXIT_SUCCESS; 
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
