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
    my $expires = $c->session_expires;
    my %options = (expires_at => $expires) if $expires;
    $c->_chi->set($key, $data, \%options);
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

sub delete_expired_sessions { }    # unsupported

=head2 get_and_set_session_data
This is the optional method for atomic write semantics. See
L<Catalyst::Plugin::Session::AtomicWrite>.

=cut

sub get_and_set_session_data {
    my ($c, $sid, $sub) = @_;
    my $expires = $c->session_expires;
    my %options = (expires_at => $expires) if $expires;
    $c->_chi->compute($sid,\%$expires, $sub);
}

=head2 setup_session

Sets up the session cache file.

=cut

sub setup_session {
    my $c = shift;
    $c->maybe::next::method(@_);
    my $config = $c->_session_plugin_config;
    my $args = $config->{chi_args};
    #deleting Catalyst::Plugin::Session variables
    my $chi_class = $config->{chi_class} || "CHI";
    my $chi = $chi_class->new(%$args);
    $c->_chi($chi);
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

Use this CHI subclass instead.

=head2 Other Options

Accepts L<Catalyst::Plugin::Session/CONFIGURATION> configurations and any valid option from L<CHI/CONSTRUCTOR>.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::Plugin::Session>, L<CHI>.

=head1 AUTHOR

James Rouzier, C<< <rouzier at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-catalyst-plugin-session-store-chi at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Catalyst-Plugin-Session-Store-CHI>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Catalyst::Plugin::Session::Store::CHI


You can also look for information at:


=head2 * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Catalyst-Plugin-Session-Store-CHI>

=head2 * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Catalyst-Plugin-Session-Store-CHI>

=head2 * CPAN Ratings

L<http://cpanratings.perl.org/d/Catalyst-Plugin-Session-Store-CHI>

=head2 * Search CPAN

L<http://search.cpan.org/dist/Catalyst-Plugin-Session-Store-CHI/>


=head1 LICENSE AND COPYRIGHT

Copyright 2014 James Rouzier.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of Catalyst::Plugin::Session::Store::CHI
