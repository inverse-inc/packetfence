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
#    "Authentication",   # authentication sources and rights ()
);

# Set the permissions for the different config files
# TODO: Should probably go into pf::config....
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

sub _uiFieldOrderType {
    return undef;
}

=item readArray

Return an array of arrays. Each array respects the field order defined in ui.conf.

=cut

sub readArray {
    my ( $self, $id ) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $result, @sections);
    my $field_order_type = $self->_uiFieldOrderType();

    if ($field_order_type) {
        my $conf = $self->loadConfig;
        my @columns = pf::config::ui->instance->field_order('$field_order_type get');
        my @resultset= ([@columns]);

        if ($id eq 'all') {
            @sections = keys %$conf;
        } elsif (exists $conf->{$id}) {
            @sections = ($id);
        }

        foreach my $section ( @sections) {
            my @values = map { $_ || ''} @{$conf->{$section}}{@columns};
            push @resultset, \@values;
        }

        if ($#resultset > 0) { # ignore first array with column names
            ($status,$result) = ($STATUS::OK, [@resultset]);
        } else {
            ($status,$result) = ($STATUS::NOT_FOUND, "\"$id\" does not exists");
            $logger->warn("$result");
        }
    }
    else {
        ($status, $result) = ($STATUS::PRECONDITION_FAILED, "No UI field order defined");
    }

    return ($status, $result);
}

=item readHash

Return an array of hashes. Each hash corresponds to a configuration file section.

=cut

sub readHash {
    my ($self, $id ) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status, $result);
    my (@sections, @resultset);
    my $conf = $self->loadConfig;

    if ($id eq 'all') {
        @sections = keys %$conf;
    } elsif (exists $conf->{$id}) {
        @sections = ($id);
    }

    foreach my $section (@sections) {
        my %values = (id => $section, %{$conf->{$section}});
        push @resultset, \%values;
    }

    if (scalar @resultset > 0) {
        ($status, $result) = ($STATUS::OK, \@resultset);
    } else {
        ($status, $result) = ($STATUS::NOT_FOUND, "\"$id\" does not exists");
        $logger->warn("$result");
    }

    return ($status,$result);
}

=item deleteItem

Delete an existing item

=cut

sub deleteItem {
    my ( $self, $id ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status,$status_msg);

    my $conf = $self->loadConfig;
    my $tied_conf = tied(%$conf);

    if ( $tied_conf->SectionExists($id) ) {
        $tied_conf->DeleteSection($id);
        $self->updateConfig($conf);
    } else {
        $status_msg = "\"$id\" does not exists";
        $logger->warn("$status_msg");
        return ($STATUS::NOT_FOUND, $status_msg);
    }

    $status_msg = "\"$id\" successfully deleted";
    $logger->info("$status_msg");
    return ($STATUS::OK, $status_msg);
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
    $logger->debug("Config file $self->{config_file} has been read and put into " . $self->_getName . " cache.");
}

=item createItem

=cut

sub createItem {
    my ( $self, $id, $assignments ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status,$status_msg);
    if($self->valid_id($id)) {
        my $conf = $self->loadConfig;
        my $tied_conf = tied(%$conf);

        if ( !$tied_conf->SectionExists($id) ) {
            $tied_conf->AddSection($id);
            while ( my ($param, $value) = each %$assignments ) {
                $tied_conf->newval( $id, $param, defined $value ? $value : '' );
            }
            $self->updateConfig($conf);
            ($status,$status_msg) = ($STATUS::OK,"\"$id\" successfully created");
        } else {
            ($status,$status_msg) = ($STATUS::PRECONDITION_FAILED,"\"$id\" already exists");
            $logger->warn("$status_msg");
        }

        $logger->info("$status_msg");
    }
    else {
        ($status,$status_msg) = ($STATUS::FORBIDDEN, "This method does not handle \"$id\"");
    }
    return ($status, $status_msg);
}

=item updateItem

Update/edit/modify an existing floating network device.

=cut

sub updateItem {
    my ( $self, $id, $assignments ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status,$status_msg) = ($STATUS::OK,"");
    if($id eq 'all') {
        $status = $STATUS::FORBIDDEN;
        $status_msg = "This method does not handle \"$id\"";
    }
    else {
        my $conf = $self->loadConfig;
        my $tied_conf = tied(%$conf);
        if ( $tied_conf->SectionExists($id) ) {
            while ( my ($param, $value) = each %$assignments ) {
                if ( defined( $conf->{$id}->{$param} ) ) {
                    $tied_conf->setval( $id, $param, $value );
                } else {
                    $tied_conf->newval( $id, $param, $value );
                }
            }
            $self->writeConfig;
        } else {
            $status_msg = "\"$id\" does not exists";
            $status =  $STATUS::NOT_FOUND;
            $logger->warn("$status_msg");
        }
        $status_msg = "\"$id\" successfully modified";
        $logger->info("$status_msg");
    }
    return ($status, $status_msg);
}

=item readDefault

Read default configurations for module and returns an hashref.

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

Read documentation file and returns an hashref.

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

    my $cache = CHI->new( _get_chi_cache_definition($self->_getName) );
    $cache->clear;
    $cache->set('timestamp', time);
    $cache->set_multi(\%$config);

    # TODO: Check to see latest modified timestamp on the file
    $self->writeConfig;
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
        my $chi_timestamp = $cache->get('timestamp');
    }

    # Get config file latest modified timestamp
    if ( -e $self->config_file ) {
        my $file_timestamp = (stat $self->config_file)[9];

        if ( $file_timestamp > $chi_timestamp ) {
            $logger->warn("Config file $self->{config_file} seems to has been modified since last loaded into cache.");
        }
    } else {
        $logger->info("Unable to determine config file $self->{config_file} last modification timestamp. ".
            "Maybe the file just does not exist. We will write the cache to the file.");
    }
}


=back

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

=head1 COPYRIGHT

Copyright (C) 2012-2013 Inverse inc.

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
