package pfappserver::Model::Config::IniStyleBackend;

=head1 NAME

pfappserver::Model::Config::IniStyleBackend - Catalyst Model

=head1 DESCRIPTION

Meta module for configuration. This one contains parent methods for every configuration modules (cache related).

Caches are initialized at pfappserver runtime using the 'after setup_finalize' method modifier in html/pfappserver/lib/pfappserver.pm

=cut

use CHI;
use Config::IniFiles;
use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;

use pf::config;
use pf::config::ui;
use pf::error qw(is_error is_success);

extends 'Catalyst::Model';

has 'config_file'   => ( is => 'ro', isa => 'Str', builder => '_myConfigFile', required => 1 );
has 'default_file'  => ( is => 'ro', isa => 'Str', builder => '_myDefaultFile' );
has 'doc_file'      => ( is => 'ro', isa => 'Str', builder => '_myDocFile' );

# Defaults meant to be overridden
# Those are required for the builder attributes option on runtime
sub _myConfigFile   { return "" };
sub _myDefaultFile  { return "" };
sub _myDocFile      { return "" };

# Thoses are the configurations modules for which we act as a backend
# This array is used by the 'after setup_finalize' method modifier in html/pfappserver/lib/pfappserver.pm.
# See getConfigurationModules
my @configuration_modules = (
    "Pf",               # global PacketFence configurations (pf.conf)
#    "Authentication",   # authentication sources and rights ()
    "Networks",         # dhcp/dns/networks types configurations (networks.conf)
    "Switches",         # managed network equipements configurations (switches.conf)
    "Violations",       # violations/policies/isolation rules configurations (violations.conf)
    "FloatingDevices",  # floating devices equipments configurations (floating_devices.conf)
#    "PortalProfiles",   # custom portal profile configuration (portal_profiles.conf)
);

# Set the permissions for the different config files
Readonly::Scalar our $WRITE_PERMISSIONS => '0644';

# TODO: Meant to be removed... (dwuelfrath@inverse.ca 2012.12.20)
has '_cached_conf' => (is => 'rw', isa => 'HashRef');


=head1 METHODS

=over

=item getConfigurationModules

Returns the configuration modules array for which we act as a backend

=cut
sub getConfigurationModules {
    my ( $self ) = @_;

    return @configuration_modules;
}

=item _get_chi_cache_definition

Return the appropriate CHI cache definition according to the calling method/package.

=cut
sub _get_chi_cache_definition {
    my ( $name ) = @_;

    my %chi_cache_definition = (
        driver => 'Memory',
        global => 1,
        namespace => $name
    );

    return %chi_cache_definition;
}

=item readConfig

Read the config file and cache the content using CHI.

.ini style flat config file -> cache (CHI)

=cut
sub readConfig {
    my ( $self ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $cache = CHI->new( _get_chi_cache_definition($self->_getName) );
    my ($default, %config);

    # If provided, will load a default config file to import within the desired config
    if ( $self->default_file ne "" ) {
        $default= $self->readDefault;
        $default = tied(%$default);
    }

    # Read the existing config file
    if ( -e $self->config_file ) {
        tie %config, 'Config::IniFiles', (
            -file       => $self->config_file,
            -allowempty => 1,
            -import     => $default,
        ) or $logger->logdie("Unable to open config file $self->{config_file}: ",
            join("\n", @Config::IniFiles::errors));
        $logger->info("Read config file $self->{config_file}");
    }

    # Config file does not exists, create a new one
    # Note that the file won't be written to filesystem at this step
    else {
        tie %config, 'Config::IniFiles', (
            -import => $default,
        );
        $logger->info("No existing config file was found for $self->{config_file}. " . 
            "Will proceed with defaults if exists.")
    }

    # Remove trailing spaces of config parameters
    foreach my $section ( tied(%config)->Sections ) {
        foreach my $key ( keys %{ $config{$section} } ) {
            $config{$section}{$key} =~ s/\s+$//;
        }
    }

    # Put the config tied hash into CHI cache
    $cache->set('timestamp', time);
    $cache->set_multi(\%config);
    $logger->info("Config file $self->{config_file} has been read and put into " . $self->_getName . " cache.");
}

=item readDefault

=cut
sub readDefault {
    my ( $self ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my %default;

    if ( $self->default_file ne "" ) {
        if ( -e $self->default_file ) {
            tie %default, 'Config::IniFiles', (
                -file       => $self->default_file,
                -allowempty => 1,
            ) or $logger->logdie("Unable to open default file $self->{default_file}: ",
                join("\n", @Config::IniFiles::errors));
            $logger->info("Read default file $self->{default_file}");
        } else {
            $logger->error("Told to read default file $self->{default_file} but the file does not seems to exists. ",
                "You should check because problems may occurs.");
            return;
        }
    } else {
        $logger->warn("Told to read default file but none is specified. That may be normal for some modules but " .
            "just wanted to let you know.");
        return;
    }

    return \%default;
}

=item readDoc

=cut
sub readDoc {
    my ( $self ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my %doc;

    if ( $self->doc_file ne "" ) {
        if ( -e $self->doc_file ) {
            tie %doc, 'Config::IniFiles', (
                -file       => $self->doc_file,
                -allowempty => 1,
            ) or $logger->logdie("Unable to open documentation file $self->{doc_file}: ",
                join("\n", @Config::IniFiles::errors));
            $logger->info("Read documentation file $self->{doc_file}");
        } else {
            $logger->error("Told to read documentation file $self->{doc_file} but the file does not seems to exists. ",
                "You should check because problems may occurs.");
            return;
        }
    } else {
        $logger->warn("Told to read documentation file but none is specified. That may be normal for some modules " .
            "just wanted to let you know.");
        return;
    }

    return \%doc;
}

=item writeConfig

Write the cache (CHI) content to the config file.

cache (CHI) -> .ini style flat config file

=cut
sub writeConfig {
    my ( $self ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    my ( $chi_timestamp, $config ) = $self->loadConfig;
    my $tied_config  = tied(%$config);

    # TODO
    # Check if the flat file has been modified since loaded into cache to avoid configuration overwrite
    $self->checkTimestamp($chi_timestamp);

    # When using default configs, remove parameter that are equals to their default value
    if ( $self->default_file ne "" ) {
        my $default = $self->readDefault;
        my $tied_default = tied(%$default);

        foreach my $section ( $tied_config->Sections ) {
            next if ( !$tied_default->SectionExists($section) );

            foreach my $parameter ( $tied_config->Parameters($section) ) {
                next if ( !$tied_default->exists($section, $parameter) );
                my $config_val = $tied_config->val($section, $parameter);
                my $default_val = $tied_default->val($section, $parameter);
                if ( $config_val eq $default_val  ) {
                    $tied_config->delval($section, $parameter);
                }
            }

        }

    }

    # Delete empty sections
    foreach my $section ( $tied_config->Sections ) {
        $tied_config->DeleteSection($section) if ( scalar($tied_config->Parameters($section)) == 0 );
    }

    $tied_config->SetWriteMode($WRITE_PERMISSIONS);
    $tied_config->WriteConfig($self->config_file)
        or $logger->logdie("Unable to write config to $self->{config_file}: ",
        join("\n", @Config::IniFiles::errors));

    $status_msg = "Successfully write config file $self->{config_file}";
    $logger->info($status_msg);
    return ( $STATUS::OK, $status_msg )
}

=item loadConfig

Get config parameters from cache (CHI) for different uses.
It is also returning the timestamp of the the latest cache update.

cache (CHI) --> sub

=cut
sub loadConfig {
    my ( $self ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $cache = CHI->new( _get_chi_cache_definition($self->_getName) );
    my $config = $cache->dump_as_hash;

    tie my %config, 'Config::IniFiles';

    while ( my ($section, $keys) = each %$config ) {
        next if $section eq 'timestamp';    # We do not need the CHI timestamp in the config hash
        while ( my ($key, $value) = each %$keys ) {
            tied(%config)->newval($section, $key, $value);
        }
    }

    my $timestamp = $config->{'timestamp'};

    return ( $timestamp, \%config );
}

=item updateConfig

Update the cached config (CHI) with modified config parameters.

sub --> cache (CHI)

=cut
sub updateConfig {
    my ( $self, $config ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # TODO: Check to see latest modified timestamp on the file
    my $cache = CHI->new( _get_chi_cache_definition($self->_getName) );
    $cache->set('timestamp', time);
    $cache->set_multi(\%$config);
}

=item checkTimestamp

Compare both cache (CHI) and config file timestamp to see which one is the newer version.

=cut
sub checkTimestamp {
    my ( $self, $chi_timestamp ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    # Get CHI timestamp to check if we have the latest version / the file has not been modified
    if ( !$chi_timestamp ) {
        my $cache = CHI->new( _get_chi_cache_definition($self->_getName) );
        my $config = $cache->dump_as_hash;
        my $chi_timestamp = $config->{'timestamp'};
    }

    # Get config file latest modified timestamp
    if ( -e $self->config_file ) {
        my $file_timestamp = (stat $self->config_file)[9];

        if ( $file_timestamp > $chi_timestamp ) {
            $logger->warn("Config file $self->{config_file} seems to has been modified since last loaded into cache.");
        }
    } else {
        $logger->warn("Unable to determine config file $self->{config_file} last modification timestamp. ". 
            "Maybe the file just does not exist. We will write the cache to the file.");
    }
}


=head1 METHODS TO GET RID OF

=over


=item _load_conf

Load .ini style config file into a Config::IniFiles tied hasref.

Performs caching.

=cut
# TODO: Meant to be removed... (dwuelfrath@inverse.ca 2012.12.20)
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


=back

=head1 AUTHORS

Olivier Bilodeau <obilodeau@inverse.ca>

Derek Wuelfrath <dwuelfrath@inverse.ca>

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
