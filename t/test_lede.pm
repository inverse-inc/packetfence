package test_lede;

=head1 NAME

test_lede -

=cut

=head1 DESCRIPTION

test_lede

=cut

use strict;
use warnings;
use Mojo::Base 'Mojolicious';
use POSIX;

has 'signal_fh';

sub startup {
    my ($self) = @_;
    my $r = $self->routes;
    $r->post('/configure' => sub {
      my $c = shift;
      $c->render(json => {}, status => 200);
      $c->tx->on( finish => sub { POSIX::_exit(0) } );
    });
    my $fh = $self->signal_fh();
    print $fh "\n"; 
}


sub start_lede {
    pipe(my $r, my $w);
    $r->autoflush(1);
    $w->autoflush(1);
    my $pid = fork();
    return 0 if !defined $pid;
    if ($pid) {
        close($w);
        my $got = <$r>;
    } else {
        close($r);
        test_lede->new(signal_fh => $w)->start('daemon', '-l', "http://127.0.0.1:5150");
    }
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

