package configurator::Model::Config::Pf;
use Moose;
use namespace::autoclean;

use Config::IniFiles;

use pf::config;
use pf::config::ui;
use pf::errors;

extends 'Catalyst::Model';

=head1 NAME

pfws::Model::Config::Pf - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 METHODS

=cut

my $_pf_conf = undef;

=item _pf_conf

Load pf.conf into a Config::IniFiles tied hashref

=cut
sub _pf_conf {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    unless (defined $_pf_conf) {
        my %conf;
        tie %conf, 'Config::IniFiles', ( -file => "$conf_dir/pf.conf" );
        my @errors = @Config::IniFiles::errors;
        if ( scalar(@errors) || !%conf ) {
            $logger->logdie("Error reading pf.conf: " . join( "\n", @errors ) . "\n" );
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

sub read_interface {
    my ($self, $interface) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    $logger->debug("interface $interface requested");

    my $pf_conf = $self->_pf_conf();
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

sub delete_interface {
    my ($self, $interface) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    return ($STATUS::FORBIDDEN, "This interface can't be deleted") if ( $interface eq 'all' );

    my $interface_name = "interface $interface";
    my $pf_conf = $self->_pf_conf();
    my $tied_conf = tied(%$pf_conf);
    if ( $tied_conf->SectionExists($interface_name) ) {
        $tied_conf->DeleteSection($interface_name);
        $tied_conf->WriteConfig($conf_dir . "/pf.conf")
            or $logger->logdie(
                "Unable to write config to $conf_dir/pf.conf. "
                ."You might want to check the file's permissions."
            );
        # The following snippet updates the database
        require pf::configfile;
        import pf::configfile;
        configfile_import( $conf_dir . "/pf.conf" );
    } else {
        return ($STATUS::NOT_FOUND, "Interface not found");
    }
  
    return ($STATUS::OK, "Successfully deleted $interface");
}

sub update_interface {
    my ($self, $interface, $assignments) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    return ($STATUS::FORBIDDEN, "This interface can't be updated") if ( $interface eq 'all' );

    my $interface_name = "interface $interface";
    my $pf_conf = $self->_pf_conf();
    my $tied_conf = tied(%$pf_conf);
    if ( $tied_conf->SectionExists($interface_name) ) {
        while (my ($param, $value) = each %$assignments) {
            if ( defined( $pf_conf->{$interface_name}{$param} ) ) {
                $tied_conf->setval( $interface_name, $param, $value );
            } else {
                $tied_conf->newval( $interface_name, $param, $value );
            }
        }
        $tied_conf->WriteConfig($conf_dir . "/pf.conf")
            or $logger->logdie(
                "Unable to write config to $conf_dir/pf.conf. "
                ."You might want to check the file's permissions."
            );
        # The following snippet updates the database
        require pf::configfile;
        import pf::configfile;
        configfile_import( $conf_dir . "/pf.conf" );
    } else {
        return ($STATUS::NOT_FOUND, "Interface not found");
    }

    return ($STATUS::OK, "Successfully modified $interface");
}

sub create_interface {
    my ($self, $interface, $assignments) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    return ($STATUS::FORBIDDEN, "This is a reserved interface name") if ( $interface eq 'all' );

    my $interface_name = "interface $interface";
    my $pf_conf = $self->_pf_conf();
    my $tied_conf = tied(%$pf_conf);
    if ( !($tied_conf->SectionExists($interface_name)) ) {
        while (my ($param, $value) = each %$assignments) {
            $tied_conf->AddSection($interface_name);
            $tied_conf->newval( $interface_name, $param, $value );
        }
        $tied_conf->WriteConfig($conf_dir . "/pf.conf")
            or $logger->logdie(
                "Unable to write config to $conf_dir/pf.conf. "
                ."You might want to check the file's permissions."
            );
        require pf::configfile;
        import pf::configfile;
        configfile_import( $conf_dir . "/pf.conf" );
    } else {
        return ($STATUS::PRECONDITION_FAILED, "Interface $interface already exists");
    }

    return ($STATUS::OK, "Successfully created $interface");
}

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
