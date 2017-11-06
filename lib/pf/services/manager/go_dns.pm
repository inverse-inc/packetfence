package pf::services::manager::go_dns;
=head1 NAME

pf::services::manager::go_dns

=cut

=head1 DESCRIPTION

pf::services::manager::go_dns

=cut

use strict;
use warnings;
use Moo;
use Template;

use pf::cluster;
use pf::config qw(
    %Config
);

use pf::file_paths qw(
    $conf_dir
    $install_dir
    $var_dir
);

use pf::util;

extends 'pf::services::manager';

has '+name' => ( default => sub { 'go_dns' } );

tie our %domain_dns_servers, 'pfconfig::cached_hash', 'resource::domain_dns_servers';

sub isManaged {
    my ($self) = @_;
    return 1;
    return  isdisabled($Config{'services'}{'dns'}) && $self->SUPER::isManaged();
}

=head2 generateConfig

Generate the configuration file

=cut

sub generateConfig {
    my ($self,$quick) = @_;
    my $tt = Template->new(ABSOLUTE => 1);
    my %tags;

    foreach my $key ( keys %domain_dns_servers ) {
        my $dns = join ' ',@{$domain_dns_servers{$key}};
        $tags{'domain'} .= <<"EOT";
    proxy $key. $dns
EOT
    }

    $tt->process("$conf_dir/Corefile", \%tags, "$install_dir/bin/Corefile") or die $tt->error();
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


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

1;
