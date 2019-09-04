package pfconfig::namespaces::resource::passthroughs;

=head1 NAME

pfconfig::namespaces::resource::passthroughs

=cut

=head1 DESCRIPTION

pfconfig::namespaces::resource::passthroughs

=cut

use strict;
use warnings;

use base 'pfconfig::namespaces::resource';

=head2 init

Initialize the object

=cut

sub init {
    my ($self) = @_;
    $self->{config}         = $self->{cache}->get_cache('config::Pf');
    $self->{authentication_sources} = $self->{cache}->get_cache('resource::authentication_sources');
    $self->{provisioning} = $self->{cache}->get_cache('config::Provisioning');
}

=head2 build

Build the passthroughs hash

    {
        # All the non-wildcard passthroughs
        normal => {
            "example.com" => ["tcp:80", ...],
            ...
        },
        wildcard => {
            "wild.example.com" => ["tcp:80", ...],
            ...
        }

    }

=cut

sub build {
    my ($self) = @_;

    my @all_passthroughs = (
        @{$self->{config}->{fencing}->{passthroughs} // []},
        map{
            ($_->isa("pf::Authentication::Source::OAuthSource") || $_->isa("pf::Authentication::Source::BillingSource") )
                ? split(/\s*,\s*/, $_->{domains} // '')
                : ()
        } @{$self->{authentication_sources} // []},
    );
    push (@all_passthroughs, map{
            split(/\s*,\s*/, $self->{provisioning}->{$_}->{domains} // '')
        } keys %{$self->{provisioning}});


    return $self->_build(\@all_passthroughs);
}

sub _build {
    my ($self, $all_passthroughs) = @_;
    
    my %passthroughs = (
        normal => {},
        wildcard => {},
    );
    foreach my $passthrough (@$all_passthroughs) {
        my ($domain, $ports) = $self->_new_passthrough($passthrough);
        my $ns = "normal";
        if($domain =~ /\*\.(.*)/) {
            $ns = "wildcard";
            $domain = $1;
        }
        if(defined($passthroughs{$ns}{$domain})) {
            push @{$passthroughs{$ns}{$domain}}, @$ports;
        }
        else {
            $passthroughs{$ns}{$domain} = $ports;
        }
    }

    return \%passthroughs;
}

=head2 _new_passthrough

Extract the domain and port from a passthrough configuration

Expects the following:
- example.com
- example.com:25
- example.com:tcp:25
- example.com:udp:25

=cut

sub _new_passthrough {
    my ($self, $passthrough) = @_;

    if($passthrough =~ /(.*?):(udp:|tcp:)?([0-9]+)/) {
        my $domain = lc($1);
        # NOTE: proto contains the ':' at the end
        my $proto = $2;
        my $port = $3;
        if($proto) {
            return ($domain, [$proto.$port]);
        }
        else {
            return ($domain, ["udp:$port", "tcp:$port"]);
        }
    }
    else {
        return ($passthrough, ['tcp:80', 'tcp:443']);
    }
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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

