package pf::WebAPI::MSEHandler;

=head1 NAME

pf::WebAPI::MSEHandler

=cut

=head1 DESCRIPTION

pf::WebAPI::MSEHandler

=cut

use strict;
use warnings;

use Apache2::RequestIO();
use Apache2::RequestRec();
use Apache2::Response();
use APR::Pool ();
use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED HTTP_NOT_IMPLEMENTED HTTP_UNSUPPORTED_MEDIA_TYPE SERVER_ERROR HTTP_NOT_FOUND HTTP_NO_CONTENT);
use pf::log;
use pf::Redis;
use JSON::MaybeXS;

use Apache2::Const -compile => 'OK';
our $JSON = JSON::MaybeXS->new();

sub handler {
    my $r = shift;
    my $content = get_all_content($r);
    my $object  = $JSON->decode($content);
    my @args;
    for my $notification (@{$object->{notifications}}) {
        my $type = $notification->{notificationType};
        my $id   = "extended:mse_${type}:$notification->{deviceId}";
        my @cmd_args;
        if ($type eq 'inout' && $notification->{boundary} eq 'OUTSIDE') {
            @cmd_args = ('del', $id);
        }
        else {
            my $data = $JSON->encode($notification);
            @cmd_args = ('set', $id, $data);
        }
        push @args, \@cmd_args;
    }
    $r->pool->cleanup_register(\&cleanup, \@args);
    $r->status(Apache2::Const::HTTP_NO_CONTENT);
    return Apache2::Const::OK;
}

sub cleanup {
    my $commands = shift;
    my $redis = pf::Redis->new(server => '127.0.0.1:6379');
    for my $command (@$commands) {
        my ($cmd, @args) = @$command;
        $redis->$cmd(@args, sub {});
    }
    $redis->wait_all_responses();
    return Apache2::Const::OK;
}

sub get_all_content {
    my ($r) = @_;
    my $content = '';
    my $offset  = 0;
    my $cnt     = 0;
    do {
        $cnt = $r->read($content, 8192, $offset);
        $offset += $cnt;
    } while ($cnt == 8192);
    return $content;
}

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
