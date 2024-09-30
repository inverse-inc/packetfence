package pfconfig::namespaces::config::Authentication;

=head1 NAME

pfconfig::namespaces::config::Authentication

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Authentication

This module creates the configuration hash associated to authentication.conf

It also stores the information for @authentication_sources and %authentication_lookup

=cut

use strict;
use warnings;

use pfconfig::namespaces::config;
use pf::file_paths qw($authentication_config_file);
use pf::util qw(isdisabled);
use pf::constants::authentication;
use pf::config::crypt;
use pf::Authentication::constants;
use pf::Authentication::Action;
use pf::Authentication::Condition;
use pf::Authentication::Rule;
use pf::Authentication::utils;
use Sort::Naturally qw(nsort);
use List::MoreUtils qw(uniq);
use pf::constants::authentication;
use pf::config::crypt::object;

use base 'pfconfig::namespaces::config';

sub init {
    my ($self) = @_;
    $self->{file}            = $authentication_config_file;
    $self->{child_resources} = [
        'resource::authentication_config_hash',
        'resource::authentication_lookup',
        'resource::authentication_sources',
        'resource::authentication_sources_monitored',
        'resource::guest_self_registration',
        'resource::authentication_sources_azuread',
        'resource::authentication_sources_ldap',
        'resource::authentication_sources_radius',
        'resource::RolesReverseLookup',
    ];
}

sub build_child {
    my ($self) = @_;

    my %cfg = %{ $self->{cfg} };

    foreach my $key ( keys %cfg ) {
        $self->cleanup_after_read( $key, $cfg{$key} );
    }

    my @authentication_sources = ();
    my %authentication_lookup  = ();
    my %authentication_config_hash = ();
    my %roleReverseLookup;
    foreach my $source_id ( @{ $self->{ordered_sections} } ) {

        my $current_source_config = { %{$cfg{$source_id}} };

        # We skip groups from our ini files
        if ( $source_id =~ m/\s/ ) {
            next;
        }

        # Keep aside the source type
        my $type = $cfg{$source_id}{"type"};
        delete $cfg{$source_id}{type};

        # Instantiate the source object
        my $current_source = $self->newAuthenticationSource( $type, $source_id, $cfg{$source_id} );
        my @ldap_attributes;

        # Parse rules
        foreach my $rule_id ( $self->GroupMembers($source_id) ) {
            my ($id) = $rule_id =~ m/$source_id rule (\S+)$/;
            my $rule_config = $cfg{$rule_id};
            my $class = $rule_config->{class};
            if (ref($class) || (defined $class && $class =~ /\n/s)) {
                print STDERR "rule '$rule_id' seems to be defined multiple times skipping rule\n";
                next;
            }
            my $status = $rule_config->{status} // 'enabled';
            if (isdisabled($status)) {
                next;
            }

            my $current_rule = pf::Authentication::Rule->new( { match => $Rules::ANY, id => $id } );
            my %current_rule_config = ();
            my $cache_key = '';
            foreach my $parameter ( nsort keys( %$rule_config ) ) {
                my $config_value = $rule_config->{$parameter};
                if ( $parameter =~ m/condition(\d+)/ ) {
                    my ( $attribute, $operator, $value ) = split( ',', $config_value, 3 );
                    my $type;
                    if ($attribute =~ /^(.*?):(.*)$/) {
                        $type = $1;
                        $attribute = $2;
                        if ( $type eq 'ldap' ) {
                            push @ldap_attributes, $attribute;
                        }
                    }

                    $current_rule->add_condition(
                        pf::Authentication::Condition->new(
                            {   attribute => $attribute,
                                operator  => $operator,
                                value     => $value,
                                type      => $type,
                            }
                        )
                    );

                    $cache_key .= $config_value;
                    $current_rule_config{'conditions'}{$parameter} = $config_value;
                }
                elsif ( $parameter =~ m/action(\d+)/ ) {
                    my ( $type, $value ) = split( '=', $config_value, 2 );
                    $current_rule->add_action(
                        pf::Authentication::Action->new(
                            {
                                type  => $type,
                                (defined $value ? (value => $value) : ()),
                                class => pf::Authentication::Action->getRuleClassForAction($type),
                            },
                        )
                    );
                    if ( $type eq 'set_role') {
                        push @{$roleReverseLookup{$value}{authentication}}, $rule_id;
                    }

                    $current_rule_config{'actions'}{$parameter} = $config_value;
                } else {
                    $current_rule->{$parameter} = $current_rule_config{$parameter} = $config_value;
                }
            }

            if ($current_source->isa("pf::Authentication::Source::LDAPSource")) {
                my $usernameattribute = $current_source->usernameattribute;
                if ($usernameattribute) {
                    push @ldap_attributes, $usernameattribute;
                }

                my %seen;
                @ldap_attributes = map {  { value => $_, type => $Conditions::LDAP_ATTRIBUTE } } sort {$a cmp $b} uniq @ldap_attributes;
                $current_source->_ldap_attributes(\@ldap_attributes);
            }

            $current_rule->cache_key($cache_key);
            $current_rule_config{cache_key} = $cache_key;
            $current_source->add_rule($current_rule);
            $current_source_config->{'rules'}->{$rule_id} = \%current_rule_config;
        }

        push( @authentication_sources, $current_source );
        $authentication_lookup{$source_id} = $current_source;
        $authentication_config_hash{$source_id} = $current_source_config;
    }

    for my $source (@authentication_sources) {
        while (my ($k, $v) = each %$source) {
            next if ref $v;
            if (rindex($v, $pf::config::crypt::PREFIX, 0) == 0) {
                $source->{$k} = pf::config::crypt::object->new($v);
            }
        }
    }

    my %resources;
    $resources{authentication_sources} = \@authentication_sources;
    $resources{authentication_lookup}  = \%authentication_lookup;
    $resources{authentication_config_hash}  = \%authentication_config_hash;
    $self->{roleReverseLookup} = \%roleReverseLookup;
    return \%resources;

}

=head2 newAuthenticationSource

Returns an instance of pf::Authentication::Source::* for the given type

=cut

sub newAuthenticationSource {
    my ( $self, $type, $source_id, $attrs ) = @_;

    my $source;
    $type = lc($type);
    if ( exists $pf::constants::authentication::TYPE_TO_SOURCE{$type} ) {
        my $source_module = $pf::constants::authentication::TYPE_TO_SOURCE{$type};
        $source = $source_module->new( { id => $source_id, %{$attrs} } );
    }

    return $source;
}

sub cleanup_after_read {
    my ( $self, $id, $data ) = @_;
    my $type = $data->{type};
    if (defined $type && $type eq 'OpenID') {
        pf::Authentication::utils::inflatePersonMappings($data);
    }

    $self->expand_list( $data, qw(realms local_realm reject_realm searchattributes sources eduroam_radius_auth), (defined $type && ($type eq 'LDAP' || $type eq 'AD' || $type eq 'EDIR' || $type eq 'GoogleWorkspaceLDAP' || $type eq "Eduroam")) ? ('host') : () );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2024 Inverse inc.

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

