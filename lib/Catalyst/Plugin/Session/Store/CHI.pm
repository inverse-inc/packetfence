package Catalyst::Plugin::Session::Store::CHI;

use warnings;
use strict;
use Moose;
use MRO::Compat;
use namespace::clean -except => 'meta';
use CHI;

extends 'Catalyst::Plugin::Session::Store';
with 'MooseX::Emulate::Class::Accessor::Fast';
with 'Catalyst::ClassData';
__PACKAGE__->mk_classdata('_chi');

=head1 NAME

Catalyst::Plugin::Session::Store::CHI - The great new Catalyst::Plugin::Session::Store::CHI!

=head1 VERSION

Version 0.10

=cut

our $VERSION = '0.10';

=head1 SYNOPSIS

    use Catalyst qw/Session Session::Store::CHI::File Session::State::Foo/;

    MyApp->config->{'Plugin::Session'} = {
        <chi args>
    };

    # ... in an action:
    #     $c->session->{foo} = 'bar'; # will be saved
}

=head1 METHODS
These are implementations of the required methods for a store. See
L<Catalyst::Plugin::Session::Store>.


=cut

=head2 get_session_data

get session data from chi

=cut

sub get_session_data {
    my ($c, $sid) = @_;
    $c->_chi->get($sid);
}

=head2 store_session_data

store session data into chi

=cut

sub store_session_data {
    my ($c, $key, $data) = @_;
    $c->_chi->set($key, $data);
}

=head2 delete_session_data

=cut

sub delete_session_data {
    my ($c, $sid) = @_;
    $c->_chi->remove($sid);
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
    $c->_chi->compute($sid,undef, $sub);
}

=head2 setup_session

Sets up the session cache file.

=cut

sub setup_session {
    my $c = shift;
    $c->maybe::next::method(@_);
    my $config = $c->_session_plugin_config;
    my $args = $config->{chi_args};
    my $chi_class = $config->{chi_class} || "CHI";
    my $chi = $chi_class->new(%$args);
    $c->_chi($chi);
    #if the chi did not define a expire_in then use the one defined in session
    my $expire = delete $config->{expire};
    my $expires_in = $chi->expires_in;
    if($expires_in) {
        $expire = ref($expires_in) ? $expires_in->seconds : $expires_in;
    } else {
        $chi->expires_in($expire);
    }
    $config->{expires} = $expire;
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
