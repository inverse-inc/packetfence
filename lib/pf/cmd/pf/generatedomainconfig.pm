package pf::cmd::pf::generatedomainconfig;
=head1 NAME

pf::cmd::pf::generatedomainconfig

=head1 SYNOPSIS

 pfcmd generatedomainconfig

generates the OS configuration for the domain binding

=head1 DESCRIPTION

pf::cmd::pf::generatedomainconfig

=cut

use strict;
use warnings;

use base qw(pf::cmd);

use pf::domain;
use pf::util;
use pf::constants::exit_code qw($EXIT_SUCCESS);

sub _run {
    my ($self) = @_;
    pf::domain::generate_krb5_conf();
    pf::domain::generate_smb_conf();
    pf::domain::generate_resolv_conf();
    pf_run("sudo /usr/local/pf/bin/pfcmd service iptables restart");
    pf::domain::restart_winbinds();
    return $EXIT_SUCCESS; 
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2019 Inverse inc.

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

