package Catalyst::Plugin::Session::Store::MAC_Based;

use warnings;
use strict;
use Moose;
use MRO::Compat;
use namespace::clean -except => 'meta';
use CHI;
use pf::log;

extends 'Catalyst::Plugin::Session::Store::CHI';

=head1 NAME

Catalyst::Plugin::Session::Store::PF

=head1 VERSION

Version 0.10

=cut

our $VERSION = '0.10';

=head1 METHODS
These are implementations of the required methods for a store. See
L<Catalyst::Plugin::Session::Store>.


=cut

=head2 get_session_data

get session data from chi

=cut

sub get_session_data {
    my ($c, $sid) = @_;
    get_logger->info("Using SID $sid");
    $c->_chi->get(extract_prefix($sid).$c->portalSession->clientMac);
}

=head2 store_session_data

store session data into chi

=cut

sub store_session_data {
    my ($c, $sid, $data) = @_;
    get_logger->info("Using SID $sid");
    $c->_chi->set(extract_prefix($sid).$c->portalSession->clientMac, $data);
}

=head2 delete_session_data

=cut

sub delete_session_data {
    my ($c, $sid) = @_;
    get_logger->info("Using SID $sid");
    $c->_chi->remove(extract_prefix($sid).$c->portalSession->clientMac);
}

=head2 delete_expired_sessions

unsupported

=cut

sub delete_expired_sessions {
    my ($c) = @_;
    $c->_chi->purge();
}

=head2 get_and_set_session_data
This is the optional method for atomic write semantics. See
L<Catalyst::Plugin::Session::AtomicWrite>.

=cut

sub get_and_set_session_data {
    my ($c, $sid, $sub) = @_;
    get_logger->info("Using SID $sid");
    $c->_chi->compute(extract_prefix($sid).$c->portalSession->clientMac,undef, $sub);
}

sub extract_prefix {
    my ($sid) = @_;
    if($sid =~ /^(.*:)/){
        return $1;
    }
    return undef;
}

=head1 CONFIGURATION

    $c->config('Plugin::Session' => {
        chi_args =>  {
            expires => 1234,
            driver => 'Memory',
            global => 1
        }
    });

    $c->config('Plugin::Session' => {
        chi_args =>  {
            driver => 'File',
            root_dir => '/path/to/root'
        }
    });


    $c->config('Plugin::Session' => {
        chi_args =>  {
            driver => 'FastMmap',
            root_dir => '/path/to/root',
            cache_size => '1k'
        }
    });

    $c->config('Plugin::Session' => {
        chi_args =>  {
            driver  => 'Memcached::libmemcached',
            servers => [ "10.0.0.15:11211", "10.0.0.15:11212" ],
            l1_cache => { driver => 'FastMmap', root_dir => '/path/to/root' }
        }
    });

    $c->config('Plugin::Session' => {
        chi_args =>  {
            driver  => 'DBI',
            dbh => $dbh
        }
    });

    $c->config('Plugin::Session' => {
        chi_args =>  {
            driver  => 'BerkeleyDB',
            root_dir => '/path/to/root'
        }
    });

=head2 chi_class

Use this CHI subclass.

=head2 chi_args

Accepts any valid option from L<CHI/CONSTRUCTOR>

=head2 Other Options

Accepts any valid option from L<Catalyst::Plugin::Session/CONFIGURATION>

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Plugin::Session>, L<CHI>.

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
