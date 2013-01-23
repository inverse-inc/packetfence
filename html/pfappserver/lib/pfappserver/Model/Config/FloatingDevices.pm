package pfappserver::Model::Config::FloatingDevices;

=head1 NAME

pfappserver::Model::Config::FloatingDevices - Catalyst Model

=head1 DESCRIPTION

Configuration module for operations involving conf/floating_devices.conf.

=cut

use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;
use Readonly;

use pf::config;
use pf::config::ui;
use pf::error qw(is_error is_success);

extends 'pfappserver::Model::Config::IniStyleBackend';

Readonly::Scalar our $NAME => 'FloatingDevices';

sub _getName        { return $NAME };
#sub _myConfigFile   { return "/usr/local/pf/cong/floating_devices_file.conf" };
sub _myConfigFile   { return $pf::config::floating_devices_config_file };


=head1 METHODS

=cut

=item create

Create a new floating network device.

=cut
sub create {
    my ( $self, $floating_device, $assignments ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    return ($STATUS::FORBIDDEN, "This method does not handle floating device \"$floating_device\"")
        if ( $floating_device eq 'all' );

    my $floating_devices_conf = $self->loadConfig;
    my $tied_conf = tied(%$floating_devices_conf);

    if ( !$tied_conf->SectionExists($floating_device) ) {
        $tied_conf->AddSection($floating_device);
        while ( my ($param, $value) = each %$assignments ) {
            $tied_conf->newval( $floating_device, $param, $value );
        }
        $self->updateConfig(%$floating_devices_conf);
    } else {
        $status_msg = "Floating device \"$floating_device\" already exists";
        $logger->warn("$status_msg");
        return ($STATUS::PRECONDITION_FAILED, $status_msg);
    }

    $status_msg = "Floating device \"$floating_device\" successfully created";
    $logger->info("$status_msg");
    return ($STATUS::OK, $status_msg);
}

=item read

Return an array of configured floating network devices (and their configurations) or only one if specified.

=cut
sub read {
    my ( $self, $floating_device ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    my $floating_devices_conf = $self->loadConfig;
    my @columns = pf::config::ui->instance->field_order('floatingnetworkdeviceconfig get');
    my @resultset = [@columns];

    foreach my $section ( keys %$floating_devices_conf ) {
        if ( ($floating_device eq 'all') || ($floating_device eq $section) ) {
            my @values;
            foreach my $column (@columns) {
                push @values, ( $floating_device_conf->{$section}->{$column} || '' );
            }
            push @resultset, [@values];
        }
    }

    if ( $#resultset > 0 ) {
        return ($STATUS::OK, \@resultset);
    }
    else {
        $status_msg = "Floating device \"$floating_device\" does not exists";
        $logger->warn("$status_msg");
        return ($STATUS::NOT_FOUND, $status_msg);
    }

}

=item update

Update/edit/modify an existing floating network device.

=cut
sub update {
    my ( $self, $floating_device, $assignments ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    return ($STATUS::FORBIDDEN, "This method does not handle floating device \"$floating_device\"")
        if ( $floating_device eq 'all' );

    my $floating_devices_conf = $self->loadConfig;
    my $tied_conf = tied(%$floating_devices_conf);

    if ( $tied_conf->SectionExists($floating_device) ) {
        while ( my ($param, $value) = each %$assignments ) {
            if ( defined( $floating_devices_conf->{$floating_device}->{$param} ) ) {
                $tied_conf->setval( $floating_device, $param, $value );
            } else {
                $tied_conf->newval( $floating_device, $param, $value );
            }
        }
        $self->updateConfig(%$floating_devices_conf);
    } else {
        $status_msg = "Floating device \"$floating_device\" does not exists";
        $logger->warn("$status_msg");
        return ($STATUS::NOT_FOUND, $status_msg);
    }

    $status_msg = "Floating device \"$floating_device\" successfully modified";
    $logger->info("$status_msg");
    return ($STATUS::OK, $status_msg);
}

=item delete

Delete an existing floating network device.

=cut
sub delete {
    my ( $self, $floating_device ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    return ($STATUS::FORBIDDEN, "This method does not handle floating device \"$floating_device\"")
        if ( $floating_device eq 'all' );

    my $floating_devices_conf = $self->loadConfig;
    my $tied_conf = tied(%$floating_devices_conf);

    if ( $tied_conf->SectionExists($floating_device) ) {
        $tied_conf->DeleteSection($floating_device);
        $self->updateConfig(%$floating_devices_conf);
    } else {
        $status_msg = "Floating device \"$floating_device\" does not exists";
        $logger->warn("$status_msg");
        return ($STATUS::NOT_FOUND, $status_msg);
    }

    $status_msg = "Floating device \"$floating_device\" successfully deleted";
    $logger->info("$status_msg");
    return ($STATUS::OK, $status_msg);
}


=back

=head1 AUTHORS

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
