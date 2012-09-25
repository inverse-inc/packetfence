package pfappserver::Model::Config::IniStyleBackend;

=head1 NAME

pfappserver::Model::Config::IniStyleBackend - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut
use Config::IniFiles;
use Moose;
use namespace::autoclean;

use pf::config;
use pf::config::ui;
use pf::error qw(is_error is_success);

extends 'Catalyst::Model';

has 'config_file' => (
    is => 'ro', 
    isa => 'Str', 
    required => 1,
    builder => '_myConfigFile',
);
has '_cached_conf' => (is => 'rw', isa => 'HashRef');

=head1 METHODS

=over

=item _myConfigFile

TEMP TO ALLOW CORRECT STARTUP

=cut
sub _myConfigFile { return " "; }

=item _load_conf

Load .ini style config file into a Config::IniFiles tied hasref.

Performs caching.

=cut
sub _load_conf {
    my ( $self ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    unless ( defined $self->_cached_conf ) {
        my %conf;

        # Load existing file
        if ( -e $self->config_file ) {
            tie %conf, 'Config::IniFiles', ( -file => $self->config_file, -allowempty => 1 )
                or $logger->logdie("Unable to open config file $self->{config_file}: ", 
                join("\n", @Config::IniFiles::errors));
            $logger->info("Loaded existing $self->{config_file} file");
        }
        # No existing file, create one
        else {
            tie %conf, 'Config::IniFiles';
            tied(%conf)->SetFileName($self->config_file)
                or $logger->logdie("Unable to open config file $self->{config_file}: ",
                join("\n", @Config::IniFiles::errors));
            $logger->info("Created a new $self->{config_file} file");
        }

        foreach my $section ( tied(%conf)->Sections ) {
            foreach my $key ( keys %{ $conf{$section} } ) {
                $conf{$section}{$key} =~ s/\s+$//;
            }
        }

        $self->_cached_conf(\%conf);
    }

    return $self->_cached_conf;
}

1;
__END__

=item create

=cut
sub create {
    my ( $self, $network, $assignments ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    # This method does not handle the network 'all'
    return ($STATUS::FORBIDDEN, "This method does not handle network $network") 
        if ( $network eq 'all' );

    my $networks_conf = $self->_load_networks_conf();
    my $tied_conf = tied(%$networks_conf);

    if ( !$tied_conf->SectionExists($network) ) {
        $tied_conf->AddSection($network);
        while ( my ($param, $value) = each %$assignments ) {
            $tied_conf->newval( $network, $param, $value );
        }
        $self->_write_networks_conf();
    } else {
        $status_msg = "Network $network already exists";
        $logger->warn("$status_msg");
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    $status_msg = "Network $network successfully created";
    $logger->info("$status_msg");
    return ($STATUS::OK, $status_msg);
}

=item delete

=cut
sub delete {
    my ( $self, $network ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    # This method does not handle the network 'all'
    return ($STATUS::FORBIDDEN, "This method does not handle network $network")  
        if ( $network eq 'all' );

    my $networks_conf = $self->_load_networks_conf();
    my $tied_conf = tied(%$networks_conf);

    if ( $tied_conf->SectionExists($network) ) {
        $tied_conf->DeleteSection($network);
        $self->_write_networks_conf();
    } else {
        $status_msg = "Network $network does not exists";
        $logger->warn("$status_msg");
        return ($STATUS::NOT_FOUND, $status_msg);
    }

    $status_msg = "Network $network successfully deleted";
    $logger->info("$status_msg");
    return ($STATUS::OK, $status_msg);
}

=item get_types

Returns an hashref with

    $interface => $type

For example

    eth0 => vlan-isolation

=cut
sub get_types {
    my ( $self, $interfaces_ref ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $types_ref = {};
    foreach my $interface ( sort keys(%$interfaces_ref) ) {

        # skip if we don't have a network address set
        next if (!defined($interfaces_ref->{$interface}->{'network'}));

        my ($status, $type) = $self->read_value($interfaces_ref->{$interface}->{'network'}, 'type');
        if ( is_success($status) ) {
            $types_ref->{$interface} = $type;
        }
    }

    return ($STATUS::OK, $types_ref);
}

=item list_networks

Temporary method to return the list of currently configured networks in networks.conf since read_network returns
an array of array with the columns first...

=cut
sub list_networks {
    my ( $self ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $networks_conf = $self->_load_networks_conf();
    my @networks = ();
    foreach my $section ( keys %$networks_conf ) {
        push @networks, $section;
    }

    return ($STATUS::OK, \@networks);
}


=item read_value

=cut
sub read_value {
    my ( $self, $section, $param ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    my $networks_conf = $self->_load_networks_conf();

    # Warning: autovivification causes interfaces to be created if the section
    # is not looked on her own first when the file is written later.
    if (!defined($networks_conf->{$section}) || !defined($networks_conf->{$section}->{$param})) {
        $status_msg = "$section.$param does not exists";
        $logger->warn("$status_msg");
        return ($STATUS::NOT_FOUND, $status_msg);
    }

    $status_msg = $networks_conf->{$section}->{$param} || '';

    return ($STATUS::OK, $status_msg);    
}

=item read_network

=cut
sub read_network {
    my ( $self, $network ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $networks_conf = $self->_load_networks_conf();
    my @columns = pf::config::ui->instance->field_order('networkconfig get'); 
    my @resultset = [@columns];

    foreach my $section ( keys %$networks_conf ) {
        if ( ($network eq 'all') || ($network eq $section) ) {
            my @values;
            foreach my $column (@columns) {
                push @values, ( $networks_conf->{$section}->{$column} || '' );
            }
            push @resultset, [@values];
        }
    }

    if ( $#resultset > 0 ) {
        return ($STATUS::OK, \@resultset);
    }
    else {
        return ($STATUS::NOT_FOUND, "Unknown network $network");
    }
}

=item update

=cut
sub update {
    my ( $self, $network, $assignments ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    # This method does not handle the network 'all'
    return ($STATUS::FORBIDDEN, "This method does not handle network $network")
        if ( $network eq 'all' );

    my $networks_conf = $self->_load_networks_conf();
    my $tied_conf = tied(%$networks_conf);

    if ( $tied_conf->SectionExists($network) ) {
        while ( my ($param, $value) = each %$assignments ) {
            if ( defined( $networks_conf->{$network}->{$param} ) ) {
                $tied_conf->setval( $network, $param, $value );
            } else {
                $tied_conf->newval( $network, $param, $value );
            }
        }
        $self->_write_networks_conf();
    } else {
        $status_msg = "Network $network does not exists";
        $logger->warn("$status_msg");
        return ($STATUS::NOT_FOUND, $status_msg);
    }

    $status_msg = "Network $network successfully modified";
    $logger->info("$status_msg");
    return ($STATUS::OK, $status_msg);
}

=item update_network

=cut
sub update_network {
    my ( $self, $network, $new_network ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    # This method does not handle the network 'all'
    return ($STATUS::FORBIDDEN, "This method does not handle network $network")
        if ( $network eq 'all' );

    my $networks_conf = $self->_load_networks_conf();
    my $tied_conf = tied(%$networks_conf);
    if (exists $networks_conf->{$network}) {
        my $network_ref = $networks_conf->{$network};
        $networks_conf->{$new_network} = $network_ref;
        delete $networks_conf->{$network};
        $self->_write_networks_conf();
    }
    else {
        $logger->error("Network $network not found");
    }

    $status_msg = "Network $network successfully renamed to $new_network";
    $logger->info("$status_msg");
    return ($STATUS::OK, $status_msg);
}

=item _write_networks_conf

=cut
sub _write_networks_conf {
    my ( $self ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $networks_conf = $self->_load_networks_conf();
    tied(%$networks_conf)->WriteConfig($network_config_file)
        or $logger->logdie(
            "Unable to write configs to $network_config_file. You might want to check the file's permissions."
        );
    $logger->info("Successfully write configs to $network_config_file");
}

=item exist

=cut
sub exist {
    my ( $self, $network ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $networks_conf = $self->_load_networks_conf();
    my $tied_conf = tied(%$networks_conf);

    return $TRUE if ( $tied_conf->SectionExists($network) );
    return $FALSE;
}

=back

=head1 AUTHORS

Derek Wuelfrath <dwuelfrath@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

Francis Lachapelle <flachapelle@inverse.ca>

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
