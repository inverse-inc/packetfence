package configurator::Model::Config::Networks;

=head1 NAME

configurator::Model::Config::Networks - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

use Config::IniFiles;
use Moose;
use namespace::autoclean;

use pf::config;
use pf::config::ui;
use pf::error qw(is_error);

extends 'Catalyst::Model';

my $_networks_conf;

=head1 METHODS

=over

=item create_network

=cut
sub create_network {
    my ( $self, $network, $assignments ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    return ($STATUS::FORBIDDEN, "This is a reserved network name") if ( $network eq 'all' );

    my $networks_conf = $self->_load_conf();
    my $tied_conf = tied(%$networks_conf);
    if ( !($tied_conf->SectionExists($network)) ) {
        while (my ($param, $value) = each %$assignments) {
            $tied_conf->AddSection($network);
            $tied_conf->newval( $network, $param, $value );
        }
        $self->_write_networks_conf();
    } else {
        return ($STATUS::PRECONDITION_FAILED, "Network $network already exists");
    }

    return ($STATUS::OK, "Successfully created $network");
}

=item delete_network

=cut
sub delete_network {
    my ( $self, $network ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    return ($STATUS::FORBIDDEN, "This network can't be deleted") if ( $network eq 'all' );

    my $networks_conf = $self->_load_conf();
    my $tied_conf = tied(%$networks_conf);
    if ( $tied_conf->SectionExists($network) ) {
        $tied_conf->DeleteSection($network);
        $self->_write_networks_conf();
    } 
    else {
        return ($STATUS::NOT_FOUND, "Network $network not found");
    }
  
    return ($STATUS::OK, "Successfully deleted $network");
}

=item _load_conf

Load networks.conf into a Config::IniFiles tied hasref.

Performs caching.

=cut
sub _load_conf {
    my ( $self ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    unless ( defined $_networks_conf ) {
        my %conf;

        # load config if it exists
        if ( -e $network_config_file ) {
            tie %conf, 'Config::IniFiles', ( -file => $network_config_file )
                or $logger->logdie("Unable to open config file $network_config_file: ", 
                join("\n", @Config::IniFiles::errors));
        }
        # starts with an empty file
        else {
            tie %conf, 'Config::IniFiles';
            tied(%conf)->SetFileName($network_config_file)
                or $logger->logdie("Unable to open config file $network_config_file: ",
                join("\n", @Config::IniFiles::errors));
        }

        foreach my $section ( tied(%conf)->Sections ) {
            foreach my $key ( keys %{ $conf{$section} } ) {
                $conf{$section}{$key} =~ s/\s+$//;
            }
        }

        $_networks_conf = \%conf;
    }

    return $_networks_conf;
}

=item read

=cut
sub read {
    my ( $self, $config_entry ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $networks_conf = $self->_load_conf();

    my @config_parameters;
    # config_entry is a scalar and all parameters were requested
    if ( !ref($config_entry) && $config_entry eq 'all' ) {
        foreach my $section ( sort keys(%$networks_conf) ) {
            foreach my $param ( keys( %{ $networks_conf->{$section} } ) ) {
                push @config_parameters, $self->_read_config_entry( $section, $param );
            }
        }
    }
    else {
        # lets build a list of the parameters to retrieve and send to the client
        my @to_retrieve;
        push @to_retrieve, $config_entry if (!ref($config_entry)); 
        push @to_retrieve, @$config_entry if (ref($config_entry) eq 'ARRAY'); 

        foreach my $config (@to_retrieve) {

            my ($section, $param) = split( /\s*\.\s*/, $config );
            if ( defined($networks_conf->{$section}->{$param}) ) {
                push @config_parameters, $self->_read_config_entry( $section, $param );
            } else {
                return ($STATUS::NOT_FOUND, "Unknown configuration parameter $section.$param!");
            }
        }
    }

    if (!@config_parameters) {
        $logger->warn("Nothing found when searching for $config_entry");
        return ($STATUS::NOT_FOUND, "No results");
    }

    return ($STATUS::OK, \@config_parameters);
}

=item _read_config_entry

=cut
sub _read_config_entry {
    my ( $self, $section, $param ) = @_;

    my $networks_conf = $self->_load_conf();

    return {
        'parameter' => $section.'.'.$param,
        'value' => $networks_conf->{$section}->{$param},
    };
}

=item read_network

=cut
sub read_network {
    my ( $self, $network ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("network $network requested");

    my $networks_conf = $self->_load_conf();
    my @columns = pf::config::ui->instance->field_order('networkconfig get'); 
    my @resultset = @columns;
    foreach my $s (keys %$networks_conf) {
        if ( $s =~ /^network (.+)$/ ) {
            my $network_name = $1;
            if ( ($network eq 'all') || ($network eq $network_name) ) {
                my @values;
                foreach my $column (@columns) {
                    push @values, ( $networks_conf->{$s}->{$column} || '' );
                }
                push @resultset, [$network_name, @values];
            }
        }
    }

    if ( $#resultset > 0 ) {
        return ($STATUS::OK, \@resultset);
    }
    else {
        return ($STATUS::NOT_FOUND, "Unknown network $network");
    }
}

=item read_value

=cut
sub read_value {
    my ( $self, $config_entry ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status, $result_ref) = $self->read($config_entry);
    # return errors to caller
    return ($status, $result_ref) if (is_error($status));

    my $config_ref = {};
    foreach my $param (@$result_ref) {
        my $value = (defined($param->{'value'})) ? $param->{'value'} : '';
        $config_ref->{$param->{'parameter'}} = $value;
    }
    return ($status, $config_ref);
}

=item update_network

=cut
sub update_network {
    my ( $self, $network, $assignments ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    return ($STATUS::FORBIDDEN, "This network can't be updated") if ( $network eq 'all' );

    my $networks_conf = $self->_load_conf();
    my $tied_conf = tied(%$networks_conf);
    if ( $tied_conf->SectionExists($network) ) {
        while (my ($param, $value) = each %$assignments) {
            if ( defined( $networks_conf->{$network}{$param} ) ) {
                $tied_conf->setval( $network, $param, $value );
            } else {
                $tied_conf->newval( $network, $param, $value );
            }
        }
        $self->_write_networks_conf();
    } else {
        return ($STATUS::NOT_FOUND, "Network $network not found");
    }

    return ($STATUS::OK, "Successfully modified $network");
}

=item _write_networks_conf

=cut
sub _write_networks_conf {
    my ( $self ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $networks_conf = $self->_load_conf();
    tied(%$networks_conf)->WriteConfig($conf_dir . "/networks.conf")
        or $logger->logdie(
            "Unable to write config to $conf_dir/networks.conf. You might want to check the file's permissions."
        );
}

=back

=head1 AUTHORS

Derek Wuelfrath <dwuelfrath@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2012 Inverse inc.

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

__PACKAGE__->meta->make_immutable;

1;
