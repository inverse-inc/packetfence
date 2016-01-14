package pf::services::manager::httpd_admin;
=head1 NAME

pf::services::manager::httpd_admin add documentation

=cut

=head1 DESCRIPTION

pf::services::manager::httpd_admin

=cut

use strict;
use warnings;
use Moo;
use Template;
use pf::config;
use pf::cluster;
use pf::file_paths;

extends 'pf::services::manager::httpd';

has '+name' => (default => sub { 'httpd.admin' } );

has '+shouldCheckup' => ( default => sub { 0 }  );

sub generateConfig {
    my ($self, $quick) = @_;
    $self->SUPER::generateConfig($quick);
    my $vars = $self->createVars();
    my $tt = Template->new(ABSOLUTE => 1);
    $tt->process("/usr/local/pf/conf/httpd.conf.d/httpd.admin.tt", $vars, "/usr/local/pf/var/conf/httpd.conf.d/httpd.admin") or die $tt->error();
}

sub createVars {
    my ($self) = @_;
    my %vars = (
        ports => $Config{ports},
        vhost => $self->vhost,
        install_dir => $install_dir,
        var_dir => $var_dir,
        server_admin => $self->serverAdmin,
        server_name  => $Config{'general'}{'hostname'} . "." . $Config{'general'}{'domain'},
    );
    return \%vars;
}

sub _build_config_file_path {
    my ($self) = @_;
    return "$var_dir/conf/httpd.conf.d/" . $self->name;
}

sub vhost {
    my ($self) = @_;
    my $vhost;
    if ( $management_network && defined($management_network->{'Tip'}) && $management_network->{'Tip'} ne '') {
        if (defined($management_network->{'Tvip'}) && $management_network->{'Tvip'} ne '') {
            $vhost = $management_network->{'Tvip'};
        } elsif ( $cluster_enabled ){
            $vhost = $ConfigCluster{'CLUSTER'}{'management_ip'};
        } else {
            $vhost = $management_network->{'Tip'};
       }
    } else {
        $vhost = "0.0.0.0";
    }
    return $vhost;
}

sub serverAdmin {
    my ($self) = @_;
    my $server_admin;
    if (defined($Config{'alerting'}{'fromaddr'}) && $Config{'alerting'}{'fromaddr'} ne '') {
        $server_admin = $Config{'alerting'}{'fromaddr'};
    }
    else {
        $server_admin = "root\@" . $Config{'general'}{'hostname'} . "." . $Config{'general'}{'domain'};
    }
    return $server_admin;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


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

1;

