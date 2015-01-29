package captiveportal::Base::Controller;

=head1 NAME

captiveportal::Base::Controller add documentation

=cut

=head1 DESCRIPTION

captiveportal::Base::Controller

=cut

use Moose;
use Moose::Util qw(apply_all_roles);
use namespace::autoclean;
use pf::authentication;
use pf::config;
use pf::enforcement qw(reevaluate_access);
use pf::iplog qw(ip2mac);
use pf::node
  qw(node_attributes node_modify node_register node_view is_max_reg_nodes_reached);
use pf::os qw(dhcp_fingerprint_view);
use pf::useragent;
use pf::util;
use pf::violation qw(violation_count);
use pf::web::constants;
use pf::web;
BEGIN { extends 'Catalyst::Controller'; }

sub showError {
    my ( $self, $c, $error ) = @_;
    my $text_message;
    if ( ref($error) ) {
        $text_message = i18n_format(@$error);
    } else {
        $text_message = i18n($error);
    }
    $c->stash(
        template    => 'error.html',
        txt_message => $text_message,
    );
    $c->detach;
}

=head2 reached_retry_limit

Test if the retry limit has been reached for a session key
If the max is undef or 0 then check is disabled

=cut

sub reached_retry_limit {
    my ( $self, $c, $retry_key, $max ) = @_;
    return 0 unless $max;
    my $cache = $c->user_cache;
    my $retries = $cache->get($retry_key) || 1;
    if($retries > $max ) {
        return 1;
    }
    $retries++;
    $cache->set($retry_key,$retries);
    return 0;
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
