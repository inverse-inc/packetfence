package CGI::Session::Driver::chi;
=head1 NAME

CGI::Session::Driver::chi

=cut

=head1 SYNOPSIS

$s = CGI::Session->new(
    "driver:chi",
    $sid, {
        driver => 'File',
        root_dir => '/path/to/root'
    });

$s = CGI::Session->new(
    "driver:chi",
    $sid, {
        chi_class => 'My::CHI',
        namespace => 'cgi',
    });



=head1 DESCRIPTION

This driver allows L<CGI::Session> to use L<CHI> as a session store

=cut

=head2 DRIVER ARGUMENTS

It accept a hash ref with the same arguements to would pass to L<CHI>

An additional arguement chi_class

=cut

use strict;
use warnings;

use strict;
use CHI;
use base qw( CGI::Session::Driver CGI::Session::ErrorHandler );

our $VERSION = '1.0.1';

sub init {
    my ($self) = @_;
    my %args = %$self;
    my $chi_class = delete $args{chi_class} || "CHI";
    my $chi = $chi_class->new(%args);
    $self->{CHI} = $chi;
}

sub store {
    my ($self, $sid, $datastr) = @_;
    return $self->{CHI}->set($sid, $datastr);
}

sub retrieve {
    my ($self, $sid) = @_;
    return $self->{CHI}->get($sid);
}

sub remove {
    my ($self, $sid) = @_;
    return $self->{CHI}->remove($sid);
}

sub traverse {
    my ($self, $coderef) = @_;
    foreach my $key ($self->{CHI}->get_keys) {
        $coderef->( $key )
    }
}

=head1 AUTHOR

James Rouzier. <rouzier@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2013 James Rouzier

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
