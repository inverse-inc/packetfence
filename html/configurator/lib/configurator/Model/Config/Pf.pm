package configurator::Model::Config::Pf;
use Moose;
use namespace::autoclean;

use Config::IniFiles;

use pf::config;
use pf::config::ui;
use pf::error qw(is_error);

extends 'Catalyst::Model';

=head1 NAME

configurator::Model::Config::Pf - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 METHODS

=cut

my $_pf_conf;
my $_defaults_conf;
my $_doc_conf;

=item _load_conf

Load pf.conf into a Config::IniFiles tied hashref.

Performs caching.

=cut
sub _load_conf {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    unless (defined $_pf_conf) {
        my %conf;

        # load config if it exists
        if ( -e $config_file ) {
            tie %conf, 'Config::IniFiles', ( -file => $config_file )
                or $logger->logdie("Unable to open config file $config_file: ", join("\n", @Config::IniFiles::errors));
        }
        # start with an empty file
        else {
            tie %conf, 'Config::IniFiles';
            tied(%conf)->SetFileName($config_file)
                or $logger->logdie("Unable to open config file $config_file: ", join("\n", @Config::IniFiles::errors));
        }

        foreach my $section ( tied(%conf)->Sections ) {
            foreach my $key ( keys %{ $conf{$section} } ) {
                $conf{$section}{$key} =~ s/\s+$//;
            }
        }
        $_pf_conf = \%conf;
    }

    return $_pf_conf;
}

=item _load_defaults

Load default configuration values provided by conf/pf.conf.defaults

Performs caching.

=cut
sub _load_defaults {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    unless (defined $_defaults_conf) {
        my %default_conf;

        tie %default_conf, 'Config::IniFiles', ( -file => $default_config_file )
            or $logger->logdie(
                "Unable to open default config file $default_config_file: ", join("\n", @Config::IniFiles::errors)
            );
        $_defaults_conf = \%default_conf;
    }

    return $_defaults_conf;
}

=item _load_doc

Load documentation of configuration values provided by conf/documentation.conf.

Performs caching.

=cut
sub _load_doc {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    unless (defined $_doc_conf) {
        my %documentation;

        tie %documentation, 'Config::IniFiles', ( -file => $conf_dir . "/documentation.conf" )
            or $logger->logdie(
                "Unable to open documentation config file $conf_dir/documentation.conf: ",
                join("\n", @Config::IniFiles::errors)
            );
        $_doc_conf = \%documentation;
    }

    return $_doc_conf;
}

=back

=head2 general configuration related methods

=over

=item read

Read configuration value(s) with all it's metadata.

$config_entry is something like general.hostname where general is the section and 
hostname the parameter.

You can ask for both a single entry (pass a scalar) or a list of entries 
(pass an arrayref).

=cut
sub read {
    my ($self, $config_entry) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $pf_conf = $self->_load_conf();
    my $defaults_conf = $self->_load_defaults();

    my @config_parameters;
    # config_entry is a scalar and all parameters were requested
    if ( !ref($config_entry) && $config_entry eq 'all' ) {
        foreach my $section ( sort keys(%$pf_conf) ) {
            foreach my $param ( keys( %{ $pf_conf->{$section} } ) ) {
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
            if ( defined($pf_conf->{$section}->{$param}) || defined($defaults_conf->{$section}->{$param}) ) {
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

=item read_value

Read a configuration value with automatic fallback to default. A convenient
accessor to confiugration when you don't need all the configuration metadata.

$config_entry is something like general.hostname where general is the section and 
hostname the parameter.

You can ask for both a single entry (pass a scalar) or a list of entries 
(pass an arrayref).

=cut
sub read_value {
    my ($self, $config_entry) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status, $result_ref) = $self->read($config_entry);
    # return errors to caller
    return ($status, $result_ref) if (is_error($status));

    my $config_ref = {};
    foreach my $param (@$result_ref) {
        my $value = (defined($param->{'value'})) ? $param->{'value'} : $param->{'default_value'};
        $config_ref->{$param->{'parameter'}} = $value;
    }
    return ($status, $config_ref);
}

=item _read_config_entry

Read a config entry and return the proper hashref meant to be turned into JSON.

=cut
sub _read_config_entry {
    my ( $self, $section, $param ) = @_;

    my $pf_conf = $self->_load_conf();
    my $defaults_conf = $self->_load_defaults();
    my $doc_conf = $self->_load_doc();

    my $options_ref = $self->_extract_config_options($section.'.'.$param);
    return {
        'parameter' => $section.'.'.$param,
        'value' => $pf_conf->{$section}->{$param},
        'default_value' => $defaults_conf->{$section}->{$param},
        'type' => $doc_conf->{$section.'.'.$param}->{'type'} || "text",
        'options' => $options_ref,
    };
}

=item help

Obtain the help of a given configuration parameter

=cut
sub help {
    my ( $self, $config_entry ) = @_;

    my $defaults_conf = $self->_load_defaults();
    my $doc_conf = $self->_load_doc();

    return ($STATUS::NOT_FOUND, "No help available for $config_entry")
        if ( !defined($doc_conf->{$config_entry}->{'description'}) );

    my $options_ref = $self->_extract_config_options($config_entry);
    my $description_ref = $self->_extract_config_desc($config_entry);

    my ($section, $param) = split( /\s*\.\s*/, $config_entry );
    return ($STATUS::OK, {
        'parameter' => $config_entry,
        'default_value' => $defaults_conf->{$section}->{$param},
        'options' => $options_ref,
        'description' => $description_ref,
    });
}

=item update

Update configuration. Supports batch updates.

$config_update_ref is an hashref with key section.param and the value as a 
value, directly.

One value will update one parameter and multiple key => value pairs will 
perform a batch update.

=cut
sub update {
    my ($self, $config_update_ref) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    while (my ($config_entry, $value) = each %$config_update_ref) {

        my ($status, $result_ref) = $self->_update($config_entry, $value);
        # return errors to caller
        return ($status, $result_ref) if (is_error($status));
    }

    # if it worked, let's write the config
    $self->_write_pf_conf();

    return ($STATUS::OK, "Successfully updated configuration");
}

=item _update

Updates a single value of the configuration tied hash. Meant to be called 
internally. Does not write the configuration to disk!

=cut
sub _update {
    my ($self, $config_entry, $value) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($section, $param) = split( /\s*\.\s*/, $config_entry );
    my $pf_conf = $self->_load_conf();
    my $defaults_conf = $self->_load_defaults();

    # if not in pf_conf OR defaults_conf consider unknown
    return ($STATUS::NOT_FOUND, "Unknown configuration parameter $config_entry!")
        if ( !defined($pf_conf->{$section}->{$param}) && !defined($defaults_conf->{$section}->{$param}) );

    if ( defined($pf_conf->{$section}->{$param}) ) {
        # a pf.conf parameter is replaced to another value and is not the default: replace with new value
        if ( $defaults_conf->{$section}->{$param} ne $value ) {   
            tied(%$pf_conf)->setval( $section, $param, $value );
        }
        # a pf.conf parameter replaced to it's default value
        # so we just delete the pf.conf version
        else {
            tied(%$pf_conf)->delval( $section, $param );
        }
    }
    # pf.conf parameter isn't set and new value is not the default: add to pf.conf
    elsif ( $defaults_conf->{$section}->{$param} ne $value ) {
        tied(%$pf_conf)->newval( $section, $param, $value );
    }

    return ($STATUS::OK, "Successfully updated configuration");
}

=back

=head2 Interface-related methods

=over

=item read_interface

Read the pf.conf configuration of an interface.

Returns an arrayref that looks like:

    [ 
        [ interface, ip, mask, type, enforcement],
        [ eth0, 10.0.0.100, 255.255.255.0, 'dhcp-listener,management', undef ], 
        [ eth1.100, 10.100.0.1, 255.255.0.0, 'internal', 'vlan' ],
    ]

=cut
sub read_interface {
    my ($self, $interface) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("interface $interface requested");

    my $pf_conf = $self->_load_conf();
    my @columns = pf::config::ui->instance->field_order('interfaceconfig get'); 
    my @resultset = @columns;
    foreach my $s ( keys %$pf_conf ) {
        if ( $s =~ /^interface (.+)$/ ) {
            my $interface_name = $1;
            if ( ( $interface eq 'all' ) || ( $interface eq $interface_name ) ) {
                my @values;
                foreach my $column (@columns) {
                    push @values, ( $pf_conf->{$s}->{$column} || '' );
                }
                push @resultset, [$interface_name, @values];
            }
        }
    }

    if ($#resultset > 0) {
        return ($STATUS::OK, \@resultset);
    }
    else {
        return ($STATUS::NOT_FOUND, "Unknown interface $interface");
    }
}

=item read_interface_value

Read the pf.conf configuration of an interface and return a single value.

=cut
sub read_interface_value {
    my ($self, $interface, $param) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("interface $interface param $param requested");

    my $pf_conf = $self->_load_conf();
    # Warning: autovivification causes interfaces to be created if the section
    # is not looked on her own first when the file is written later.
    if ( defined($pf_conf->{'interface '.$interface}) && defined($pf_conf->{'interface '.$interface}->{$param}) ) {
        return ($STATUS::OK, $pf_conf->{'interface '.$interface}->{$param});
    }
    else {
        return ($STATUS::NOT_FOUND, "Unknown parameter $param under interface $interface");
    }
}

=item delete_interface

Delete an interface section in the pf.conf configuration.

=cut
sub delete_interface {
    my ($self, $interface) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    return ($STATUS::FORBIDDEN, "This interface can't be deleted") if ( $interface eq 'all' );

    my $interface_name = "interface $interface";
    my $pf_conf = $self->_load_conf();
    my $tied_conf = tied(%$pf_conf);
    if ( $tied_conf->SectionExists($interface_name) ) {
        $tied_conf->DeleteSection($interface_name);
        $self->_write_pf_conf();
    } 
    else {
        return ($STATUS::NOT_FOUND, "Interface not found");
    }
  
    return ($STATUS::OK, "Successfully deleted $interface");
}

=item update_interface

Update an interface in pf.conf configuration.

=cut
sub update_interface {
    my ($self, $interface, $assignments) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    return ($STATUS::FORBIDDEN, "This interface can't be updated") if ( $interface eq 'all' );

    my $interface_name = "interface $interface";
    my $pf_conf = $self->_load_conf();
    my $tied_conf = tied(%$pf_conf);
    if ( $tied_conf->SectionExists($interface_name) ) {
        while (my ($param, $value) = each %$assignments) {
            if ( defined( $pf_conf->{$interface_name}{$param} ) ) {
                $tied_conf->setval( $interface_name, $param, $value );
            } else {
                $tied_conf->newval( $interface_name, $param, $value );
            }
        }
        $self->_write_pf_conf();
    } else {
        return ($STATUS::NOT_FOUND, "Interface not found");
    }

    return ($STATUS::OK, "Successfully modified $interface");
}

=item create_interface

Create an interface section in pf.conf configuration.

=cut
sub create_interface {
    my ($self, $interface, $assignments) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    return ($STATUS::FORBIDDEN, "This is a reserved interface name") if ( $interface eq 'all' );

    my $interface_name = "interface $interface";
    my $pf_conf = $self->_load_conf();
    my $tied_conf = tied(%$pf_conf);
    if ( !$tied_conf->SectionExists($interface_name) ) {
        $tied_conf->AddSection($interface_name);
        while (my ($param, $value) = each %$assignments) {
            $tied_conf->newval( $interface_name, $param, $value );
        }
        $self->_write_pf_conf();
    } else {
        return ($STATUS::PRECONDITION_FAILED, "Interface $interface already exists");
    }

    return ($STATUS::OK, "Successfully created $interface");
}

=item exist_interface

Whether or not an interface section exists in the pf.conf configuration.

=cut
sub exist_interface {
    my ($self, $interface) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $interface_name = "interface $interface";
    my $pf_conf = $self->_load_conf();
    my $tied_conf = tied(%$pf_conf);
    return $TRUE if ( $tied_conf->SectionExists($interface_name) );
    return $FALSE;
}

=item _write_pf_conf

Performs the write of the pf.conf.

=cut
sub _write_pf_conf {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $pf_conf = $self->_load_conf();
    tied(%$pf_conf)->WriteConfig($conf_dir . "/pf.conf")
        or $logger->logdie(
            "Unable to write config to $conf_dir/pf.conf. "
            ."You might want to check the file's permissions."
        );

    # The following snippet updates the database
#    require pf::configfile;
#    import pf::configfile;
#    configfile_import( $conf_dir . "/pf.conf" );
}

=head2 Class helpers

=item _extract_config_options

Simple util wrapper to return an array of options based on a given option 
string. Meant to avoid copy/pasted code and encapsulate format of options.

Returns undef if there's no options.

=cut
sub _extract_config_options {
    my ($self, $config_entry) = @_;

    my $doc_conf = $self->_load_doc();
    if (defined($doc_conf->{$config_entry}->{'options'})) {
        return [ split(/\|/, $doc_conf->{$config_entry}->{'options'}) ];
    }
    # otherwise undef
    return;
}

=item _extract_config_desc

Simple util wrapper to return the description based on a given description 
entry reference. Meant to avoid copy/pasted code and encapsulate format of 
descriptions.

Returns undef if there's no description.

=cut
sub _extract_config_desc {
    my ($self, $config_entry) = @_;

    my $doc_conf = $self->_load_doc();
    return if (!defined($doc_conf->{$config_entry}->{'description'})); 

    if ( ref($doc_conf->{$config_entry}->{'description'}) eq 'ARRAY' ) {
        return join( "\n", @{ $doc_conf->{$config_entry}->{'description'} } );
    }
    else {
        return $doc_conf->{$config_entry}->{'description'};
    }
}

=back

=head2 SUBROUTINES

Stateless small helper functions.

=over

=back

=head1 AUTHOR

Francis Lachapelle <flachapelle@inverse.ca>

Olivier Bilodeau <obilodeau@inverse.ca>

=head1 COPYRIGHT

Copyright 2012 Inverse inc.

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
