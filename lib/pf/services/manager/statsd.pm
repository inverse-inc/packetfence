package pf::services::manager::statsd;

=head1 NAME

pf::services::manager::statsd

=cut

=head1 DESCRIPTION

pf::services::manager::statsd
StatD daemon manager module for PacketFence.

=cut

use strict;
use warnings;
use pf::file_paths qw(
    $install_dir
    $conf_dir
    $generated_conf_dir
);
use pf::util;
use Moo;
use Template;
use Data::Dumper; 

extends 'pf::services::manager';

has '+name' => ( default => sub {'statsd'} );
has '+optional' => ( default => sub {'1'} );
has startDependsOnServices => (is => 'ro', default => sub { [qw(carbon_relay)] } );

has configFilePath => (is => 'rw', builder => 1, lazy => 1);
has configTemplateFilePath => (is => 'rw', builder => 1, lazy => 1);

has '+launcher' =>
    ( default => sub {"%1\$s $install_dir/lib/Etsy/statsd/bin/statsd $install_dir/var/conf/statsd_config.js >>$install_dir/logs/statsd.log 2>&1 \& "} );


sub createVars {
    my ($self) = @_;
    my %vars = (
        pid_file => "$install_dir/var/run/statsd.pid",
        name => $self->name,
    );
    return \%vars;
}

sub _build_configFilePath {
    my ($self) = @_;
    my $name = $self->name;
    return "$generated_conf_dir/${name}_config.js";
}

sub _build_configTemplateFilePath {
    my ($self) = @_;
    my $name = $self->name;
    return "$conf_dir/monitoring/${name}_config.js"; 
}

sub generateConfig {
    my ($self) = @_;
    my $vars = $self->createVars();
    my $tt = Template->new(ABSOLUTE => 1);
    #$tags{'template'}      = "$conf_dir/monitoring/statsd_config.js";
    #$tags{'pid_file'}      = "$install_dir/var/run/statsd.pid";
    
    #parse_template( \%tags, "$tags{'template'}", "$install_dir/var/conf/statsd_config.js", '//' );
    #print Dumper($self->configTemplateFilePath);
    #print Dumper($vars);
    #print Dumper($self->configFilePath);
    
    $tt->process($self->configTemplateFilePath, $vars, $self->configFilePath) or die $tt->error();
    return 1
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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
