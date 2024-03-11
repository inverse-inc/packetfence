package pf::services::manager::pfsetacls;

=head1 NAME

pf::services::manager::pfsetacls

=cut

=head1 DESCRIPTION

pf::services::manager::pfsetacls

=cut

use strict;
use warnings;
use Moo;
use pf::config qw(
    %Config
);
use pf::file_paths qw(
    $conf_dir
    $var_dir
);


extends 'pf::services::manager';

has '+name' => ( default => sub { 'pfsetacls' } );

sub generateConfig {
    my ($self, $quick) = @_;
    my $tt = Template->new(
        ABSOLUTE => 1,
    );
    my $vars = {
       env_dict => {
           SEMAPHORE_DB_DIALECT => "bolt",
           SEMAPHORE_ADMIN_PASSWORD => "$Config{'database'}{'pass'}",
           SEMAPHORE_ADMIN_NAME => "$Config{'database'}{'user'}",
           SEMAPHORE_ADMIN_EMAIL => "$Config{'alerting'}{'emailaddr'}",
           SEMAPHORE_ADMIN => "$Config{'database'}{'user'}",
       },
    };
    $tt->process("/usr/local/pf/containers/environment.template", $vars, $var_dir."/conf/".$self->name.".env") or die $tt->error();
 }

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

