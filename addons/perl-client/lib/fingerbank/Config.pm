package fingerbank::Config;

=head1 NAME

fingerbank::Config

=head1 DESCRIPTION

Reading and writing configuration parameters

=cut

use strict;
use warnings;

use Config::IniFiles;

use fingerbank::Constant qw($TRUE $FALSE);
use fingerbank::FilePath qw($CONF_FILE $CONFIG_DEFAULTS_FILE $CONFIG_DOC_FILE $COMBINATION_MAP_FILE);
use fingerbank::Log;
use fingerbank::Status;
use fingerbank::Util qw(is_enabled is_success);
use fingerbank::NullCache;
use Time::HiRes qw(time stat);

our %Config;
our $CACHE = fingerbank::NullCache->new;

=head1 METHODS

=head2 read_config

Read content of flat file into the config hash

=cut

sub read_config {
    my $logger = fingerbank::Log::get_logger;

    if ( ! -e $CONFIG_DEFAULTS_FILE ) {
        $logger->error("Fingerbank default configuration file '$CONFIG_DEFAULTS_FILE' has not been found. Cannot continue");
        return;
    }

    # Check in the cache first
    my $config_cached = $CACHE->get('fingerbank::Config::read_config');
    my $cached_at = $CACHE->get('fingerbank::Config::read_config-cached_at');
    if(defined($config_cached) && defined($cached_at)) {
        my $conf_timestamp = ( stat($CONF_FILE) )[9];
        my $conf_defaults_timestamp = ( stat($CONFIG_DEFAULTS_FILE) )[9];

        if($cached_at > $conf_timestamp && $cached_at > $conf_defaults_timestamp) {
            $logger->trace("Cache hit for fingerbank config");
            tie %Config, 'fingerbank::ConfigRestore', $config_cached;
            return;
        }
        else {
            $logger->info("Fingerbank configuration has been changed on disk... Reloading");
        }
    }

    # If a configuration file exists, load the defaults and override using the existing configuration file
    # We allow empty file in the case a 'fingerbank.conf' file is modified to reflect all the defaults parameters (which will lead to an empty 'fingerbank.conf' file) and that file is not being deleted.
    if ( (-e $CONFIG_DEFAULTS_FILE) && (-e $CONF_FILE) ) {
        $logger->debug("Existing Fingerbank configuration file. Loading it with defaults");
        tie %Config, 'Config::IniFiles', (
            -file       => $CONF_FILE,
            -import     => Config::IniFiles->new( -file => $CONFIG_DEFAULTS_FILE ),
            -allowempty => 1,
        ) or $logger->error("Invalid Fingerbank configuration file: $!");

        if ( !%Config ) {
            $logger->error("Error while reading Fingerbank configuration file. Cannot continue");
            return;
        }
    }

    # No configuration file found. Loading the defaults
    # SetFileName allow the saving of the tied hash later with the accurate file name
    else {
        $logger->debug("No existing Fingerbank configuration file. Loading defaults");
        tie %Config, 'Config::IniFiles', ( 
            -import => Config::IniFiles->new( -file => $CONFIG_DEFAULTS_FILE )
        ) or $logger->error("Invalid Fingerbank default configuration file: $!");

        if ( !%Config ) {
            $logger->error("Error while reading Fingerbank default configuration file. Cannot continue");
            return;
        }

        tied(%Config)->SetFileName($CONF_FILE);
    }
    $CACHE->set('fingerbank::Config::read_config', tied(%Config));
    $CACHE->set('fingerbank::Config::read_config-cached_at', time);
}

=head2 read_defaults

=cut

sub read_defaults {
    my $logger = fingerbank::Log::get_logger;

    my %config_defaults;

    if ( ! -e $CONFIG_DEFAULTS_FILE ) {
        $logger->error("Fingerbank default configuration file '$CONFIG_DEFAULTS_FILE' has not been found. Cannot continue");
        return;
    }

    $logger->debug("Attempting to read Fingerbank default configuration file '$CONFIG_DEFAULTS_FILE'");
    tie %config_defaults, 'Config::IniFiles', (
        -file => $CONFIG_DEFAULTS_FILE,
    ) or $logger->error("Invalid Fingerbank default configuration file: $!");

    if ( !%config_defaults ) {
        $logger->error("Error while reading Fingerbank default configuration file. Cannot continue");
        return;
    }

    return %config_defaults;
}

=head2 read_doc

=cut

sub read_doc {
    my $logger = fingerbank::Log::get_logger;

    my %config_doc;

    if ( ! -e $CONFIG_DOC_FILE ) {
        $logger->error("Fingerbank configuration documentation file '$CONFIG_DOC_FILE' has not been found. Cannot continue");
        return;
    }

    $logger->debug("Attempting to read Fingerbank configuration documentation file '$CONFIG_DOC_FILE'");
    tie %config_doc, 'Config::IniFiles', (
        -file => $CONFIG_DOC_FILE,
    ) or $logger->error("Invalid Fingerbank configuration documentation file: $!");

    if ( !%config_doc ) {
        $logger->error("Error while reading Fingerbank configuration documentation file. Cannot continue");
        return;
    }

    return %config_doc;
}

=head2 write_config

Write content of config hash to flat file

=cut

sub write_config {
    my ( $params ) = @_;
    my $logger = fingerbank::Log::get_logger;

    my ( $status, $status_msg );

    read_config();

    # Loading the defaults to compare and delete configuration parameters that are equals to their defaults.
    my %defaultConfig;
    $logger->debug("Loading default configuration to compare before write.");
    tie %defaultConfig, 'Config::IniFiles', (
        -import => Config::IniFiles->new( -file => $CONFIG_DEFAULTS_FILE )
    ) or $logger->error("Invalid Fingerbank default configuration file: $!");
    
    if ( !%defaultConfig ) {
        $status_msg = "Error while reading Fingerbank default configuration file. Cannot continue";
        $logger->error($status_msg);
        return ( $fingerbank::Status::INTERNAL_SERVER_ERROR, $status_msg );
    }

    foreach my $section ( keys %$params ) {
        while ( my ( $parameter, $value ) = each %{ $params->{$section} } ) {
            $Config{$section}{$parameter} = $value;
        }
    }

    # Sanitizing before writing
    $logger->debug("Sanitizing configuration hash before writing it");
    foreach my $section ( tied(%Config)->Sections ) {
        # Delete keys equals to their defaults
        next if ( !exists($defaultConfig{$section}) );
        foreach my $key ( keys(%{$defaultConfig{$section}}) ) {
            next if ( !exists($defaultConfig{$section}{$key}) );
            if ( $Config{$section}{$key} eq $defaultConfig{$section}{$key} ) {
                $logger->debug("'$section'-'$key' is equals to it's default value. Removing it before write");
                $logger->debug("Defaut: {$section}{$key}=" . $defaultConfig{$section}{$key});
                $logger->debug("Config: {$section}{$key}=" . $Config{$section}{$key});
                delete $Config{$section}{$key};
                tied(%Config)->DeleteParameterComment($section, $key);
            }
        }

        # Delete empty sections
        if ( scalar(keys(%{$Config{$section}})) == 0 ) {
            $logger->debug("'$section' is empty after sanitization. Removing it before write");
            delete $Config{$section};
        }
    }

    # Writing the config hash to flat file
    $logger->debug("Writing current config hash to file '$CONF_FILE'");
    if(tied(%Config)->WriteConfig($CONF_FILE)) {
        $status_msg = "Successfully written Fingerbank configuration file";
        $logger->info($status_msg);
        return ( $fingerbank::Status::OK, $status_msg );
    }
    else {
        $status_msg = "Error writing Fingerbank configuration file '$CONF_FILE'";
        $logger->error($status_msg);
        return ( $fingerbank::Status::INTERNAL_SERVER_ERROR, $status_msg);
    }

}

=head2 get_config

Returns either the complete config hash or only part of it depending on the parameters

=cut

sub get_config {
    my ( $section, $parameter ) = @_;
    my $logger = fingerbank::Log::get_logger;

    read_config();

    if ( defined($parameter) && $parameter ne "" ) {
        $logger->debug("Requested Fingerbank configuration parameter '$parameter' of section '$section'");
        return $Config{$section}{$parameter};
    }

    if ( defined($section) && $section ne "" ) {
        $logger->debug("Requested Fingerbank configuration for section '$section'");
        return $Config{$section};
    }

    $logger->debug("Requested Fingerbank configuration");
    return \%Config;
}

=head2 get_defaults

=cut

sub get_defaults {
    my ( $section, $parameter ) = @_;
    my $logger = fingerbank::Log::get_logger;

    my %config_defaults = read_defaults();
}

=head2 get_documentation

Returns

=cut

sub get_documentation {
    my ( $parameter ) = @_;
    my $logger = fingerbank::Log::get_logger;

    my %config_doc = read_doc();

    if ( defined($parameter) && $parameter ne "" ) {
        $logger->debug("Requested Fingerbank configuration documentation for parameter '$parameter'");
        return $config_doc{$parameter};
    }

    $logger->debug("Requested Fingerbank configuration documentation");
    return \%config_doc;
}

=head2 is_api_key_configured

Return TRUE or FALSE whether if the Fingerbank API key is configured or not

=cut

sub is_api_key_configured {
    my $api_key = get_config('upstream', 'api_key');
    ( defined($api_key) && $api_key ne "" ) ? return $TRUE : return $FALSE;
}

=head2 configured_for_api

Checks whether or not, the configuration allows for API calls to the Fingerbank API

=cut

sub configured_for_api {
    return (is_api_key_configured);
}

package fingerbank::ConfigRestore;

sub TIEHASH   { $_[1] }

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

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
