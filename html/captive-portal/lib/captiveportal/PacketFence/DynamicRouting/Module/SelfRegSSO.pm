package captiveportal::PacketFence::DynamicRouting::Module::SelfRegSSO;

=head1 NAME

DynamicRouting::Module::SelfRegSSO

=head1 DESCRIPTION

Root module used to authenticate a user through the portal sources (SAML, OAuth,
MFA, ...) on behalf of another portal page, typically the sponsor activation link
(/activate/email/sponsor/<code>). The activation page sends the browser here
with a callback, the chained modules authenticate the user, and the resulting
info (pid, source, mark_as_sponsor, access_durations) is stored under a random
token in the portalselfreg namespace before redirecting back to the callback.
The token namespace is separate from RootSSO's so it can never be exchanged for
an admin session. Settings come from the [self_reg_login] section.

=cut

use Moose;
extends 'captiveportal::DynamicRouting::Module::RootSSO';

use pf::CHI;
use pf::authentication;
use List::MoreUtils qw(uniq);

sub cache { return pf::CHI->new(namespace => 'portalselfreg'); }

sub sso_config_section { return 'self_reg_login' }

=head2 allowed_callback_hosts

Also allow the activation domains of the sponsor sources, since the sponsor activation link lives there

=cut

around 'allowed_callback_hosts' => sub {
    my ($orig, $self) = @_;
    my $hosts = $self->$orig();
    for my $source (@{ pf::authentication::getAuthenticationSourcesByType('SponsorEmail') }) {
        my $domain = $source->{activation_domain} // '';
        $domain =~ s/:\d+$//;
        push @$hosts, lc $domain if length $domain;
    }
    return [ uniq @$hosts ];
};

=head2 execute_actions

Record which source authenticated the user so the callback page can evaluate its rules

=cut

sub execute_actions {
    my ($self) = @_;
    my $source = $self->app->session->{source};
    $self->new_node_info->{source_id} = $source->id if defined $source;
    return $self->SUPER::execute_actions();
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2025 Inverse inc.

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

