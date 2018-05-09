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
use pf::constants::authentication;
use pf::Authentication::constants;
use pf::Authentication::Action;
use pf::Authentication::Condition;
use pf::Authentication::Rule;
use pf::constants::authentication;

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

        # Parse rules
        foreach my $rule_id ( $self->GroupMembers($source_id) ) {
            my ($id) = $rule_id =~ m/$source_id rule (\S+)$/;

            my $current_rule = pf::Authentication::Rule->new( { match => $Rules::ANY, id => $id } );
            my %current_rule_config = ();

            foreach my $parameter ( sort( keys( %{ $cfg{$rule_id} } ) ) ) {
                if ( $parameter =~ m/condition(\d+)/ ) {
                    my ( $attribute, $operator, $value ) = split( ',', $cfg{$rule_id}{$parameter}, 3 );

                    $current_rule->add_condition(
                        pf::Authentication::Condition->new(
                            {   attribute => $attribute,
                                operator  => $operator,
                                value     => $value
                            }
                        )
                    );

                    $current_rule_config{'conditions'}{$parameter} = $cfg{$rule_id}{$parameter};
                }
                elsif ( $parameter =~ m/action(\d+)/ ) {
                    my ( $type, $value ) = split( '=', $cfg{$rule_id}{$parameter}, 2 );

                    if ( defined $value ) {
                        $current_rule->add_action(
                            pf::Authentication::Action->new(
                                {   type  => $type,
                                    value => $value,
                                    class => pf::Authentication::Action->getRuleClassForAction($type),
                                }
                            )
                        );
                    }
                    else {
                        $current_rule->add_action(
                            pf::Authentication::Action->new(
                                {
                                    type    => $type,
                                    class   => pf::Authentication::Action->getRuleClassForAction($type),
                                }
                            )
                        );
                    }

                    $current_rule_config{'actions'}{$parameter} = $cfg{$rule_id}{$parameter};
                }
                elsif ( $parameter =~ m/match/ ) {
                    $current_rule->{'match'} = $cfg{$rule_id}{$parameter};
                    $current_rule_config{'match'} = $cfg{$rule_id}{$parameter};
                }
                elsif ( $parameter =~ m/description/ ) {
                    $current_rule->{'description'} = $cfg{$rule_id}{$parameter};
                    $current_rule_config{'description'} = $cfg{$rule_id}{$parameter};
                }
                elsif ( $parameter =~ m/class/ ) {
                    $current_rule->{'class'} = $cfg{$rule_id}{$parameter};
                    $current_rule_config{'class'} = $cfg{$rule_id}{$parameter};
                }
            }

            $current_source->add_rule($current_rule);
            $current_source_config->{'rules'}->{$rule_id} = \%current_rule_config;
        }

        push( @authentication_sources, $current_source );
        $authentication_lookup{$source_id} = $current_source;
        $authentication_config_hash{$source_id} = $current_source_config;
    }

    my %resources;
    $resources{authentication_sources} = \@authentication_sources;
    $resources{authentication_lookup}  = \%authentication_lookup;
    $resources{authentication_config_hash}  = \%authentication_config_hash;

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
    $self->expand_list( $data, qw(realms local_realm reject_realm) );
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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

