package pf::Authentication::Source::ZTCoreSource;

=head1 NAME

pf::Authentication::Source::ZTCoreSource

=head1 DESCRIPTION

Model for a ZTCore source

=cut

use Crypt::Mode::CBC;
use pf::Authentication::constants;
use pf::constants;
use pf::config;
use pf::util;
use MIME::Base64 qw(decode_base64);
use JSON::MaybeXS qw(decode_json);

use Moose;
extends 'pf::Authentication::Source';

has '+type' => ( default => 'ZTCore' );
has 'auth_base_url' => ( is => 'rw', required => 1, isa => 'Str', default => 'https://networkaccess.ztdemo.net' );
has 'assertion_url' => ( is => 'rw', required => 1, isa => 'Str', default => 'https://pf.example.com/ztcore/assertion');
has 'shared_secret' => ( is => 'rw', required => 1, isa => 'Str');

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::ZTCore' }

=head2 has_authentication_rules

This source does not have any authentication rules

=cut

sub has_authentication_rules { $FALSE }

=head2 authenticate

Override parent method as ZTCore cannot be used directly for authentication

=cut

sub authenticate {
    my $msg = "Can't authenticate against a ZTCore source..."; 
    get_logger->info($msg);
    return ($FALSE, $msg);
} 

=head2 match

=cut

sub match {
    my ($self, $params) = @_;
    my $result = $params->{ztcore_response};
    my @actions = ();

    if(!$result) {
        return undef;
    }

    my $access_duration = $result->{'access_duration'};
    if (defined $access_duration) {
        push @actions, pf::Authentication::Action->new({
            type    => $Actions::SET_ACCESS_DURATION,
            value   => $access_duration,
            class   => pf::Authentication::Action->getRuleClassForAction($Actions::SET_ACCESS_DURATION),
        });
    }

    my $access_level = $result->{'access_level'};
    if (defined $access_level ) {
        push @actions, pf::Authentication::Action->new({
            type    => $Actions::SET_ACCESS_LEVEL,
            value   => $access_level,
            class   => pf::Authentication::Action->getRuleClassForAction($Actions::SET_ACCESS_LEVEL),
        });
    }

    my $sponsor = $result->{'sponsor'};
    if ($sponsor == 1) {
        push @actions, pf::Authentication::Action->new({
            type    => $Actions::MARK_AS_SPONSOR,
            value   => 1,
            class   => pf::Authentication::Action->getRuleClassForAction($Actions::MARK_AS_SPONSOR),
        });
    }

    my $unregdate = $result->{'unregdate'};
    if (defined $unregdate) {
        push @actions, pf::Authentication::Action->new({
            type    => $Actions::SET_UNREG_DATE,
            value   => $unregdate,
            class   => pf::Authentication::Action->getRuleClassForAction($Actions::SET_UNREG_DATE),
        });
    }

    my $role = $result->{'role'};
    if (defined $role) {
        push @actions, pf::Authentication::Action->new({
            type    => $Actions::SET_ROLE,
            value   => $role,
            class   => pf::Authentication::Action->getRuleClassForAction($Actions::SET_ROLE),
        });
    }

    my $time_balance = $result->{'time_balance'};
    if (defined $time_balance) {
        push @actions, pf::Authentication::Action->new({type => $Actions::SET_TIME_BALANCE, value => $time_balance});
    }

    my $bandwidth_balance = $result->{'bandwidth_balance'};
    if (defined $bandwidth_balance) {
        push @actions, pf::Authentication::Action->new({type => $Actions::SET_BANDWIDTH_BALANCE, value => $bandwidth_balance});

    }

    my $tenant_id = $result->{'tenant_id'};
    if (defined $tenant_id) {
        push @actions, pf::Authentication::Action->new({type => $Actions::SET_TENANT_ID, value => $tenant_id});
    }

    return pf::Authentication::Rule->new(
        id => "default",
        class => $params->{rule_class},
        actions => \@actions,
    );
}

=head2 sso_url

Generate the Single-Sign-On URL that points to the Identity Provider

=cut

sub sso_url {
    my ($self) = @_;
    
    my $url = $self->auth_base_url;
    my $assertion_url = $self->assertion_url;
    $url .= "?url=$assertion_url";

    return $url;
}

=head2 handle_response

Handle the response from the Identity Provider and extract the username out of the assertion

=cut

sub handle_response {
    my ($self, $params) = @_;

    my $iv = decode_base64($params->{ZTCoreResponseIV});
    my $ciphertext = decode_base64($params->{ZTCoreResponseCIPHERTEXT});
    
    my $m = Crypt::Mode::CBC->new('AES');
    my $assertion = $m->decrypt($ciphertext, pack("H*", $self->shared_secret), $iv);

    my $result = decode_json($assertion);
    # TEMP HACK: ZTCore returns the user role with a lower case which doesn't match our default value. This will need to be fixed on the ZTCore policy side
    $result->{role} = $result->{role} eq "user" ? "User" : $result->{role};

    return ($result, "Success");
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2021 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

