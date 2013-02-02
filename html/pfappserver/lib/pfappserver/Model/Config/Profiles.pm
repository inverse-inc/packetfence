package pfappserver::Model::Config::Profiles;

=head1 NAME

pfappserver::Model::Config::Profiles - Catalyst Model

=head1 DESCRIPTION

Configuration module for operations involving conf/profiles.conf.

=cut

use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;
use Readonly;

use pf::config;
use pf::error qw(is_error is_success);
use pf::trigger qw(parse_triggers);

extends 'pfappserver::Model::Config::IniStyleBackend';

Readonly::Scalar our $NAME => 'Profiles';

Readonly::Scalar our $params => [ qw(description billing_engine guest_modes filter guest_self_reg)];

sub _getName        { $NAME };
sub _myConfigFile   { $pf::config::profiles_config_file };


=head1 METHODS

=over


=item update

Update/edit/modify an existing floating network device.

=cut

sub update {
    my ( $self, $id, $assignments ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status,$status_msg) = ($STATUS::OK,"");
    if(!$self->valid_id($id)) {
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

sub create {
    my ( $self, $id, $assignments ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status,$status_msg) = ($STATUS::OK,"");
    if(!$self->valid_id($id)) {
        $status = $STATUS::FORBIDDEN;
        $status_msg = "This method does not handle \"$id\"";
    }
    else {
        my $conf = $self->loadConfig;
        my $tied_conf = tied(%$conf);

        if ( !$tied_conf->SectionExists($id) ) {
            $tied_conf->AddSection($id);
            while ( my ($param, $value) = each %$assignments ) {
                $tied_conf->newval( $id, $param, defined $value ? $value : '' );
            }
            $self->writeConfig;
        } else {
            $status_msg = "\"$id\" already exists";
            $logger->warn("$status_msg");
            return ($STATUS::PRECONDITION_FAILED, $status_msg);
        }

        $status_msg = "\"$id\" successfully created";
        $logger->info("$status_msg");
    }
    return ($STATUS::OK, $status_msg);
}

sub loadConfig {
    my ($self) = @_;
    return $self->_load_conf;
}

sub valid_id { 1 }

=item remove

Delete an existing floating network device.

=cut
sub remove {
    my ( $self, $id ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status,$status_msg);

    my $ids_conf = $self->loadConfig;
    my $tied_conf = tied(%$ids_conf);

    if ( $tied_conf->SectionExists($id) ) {
        $tied_conf->DeleteSection($id);
        $self->writeConfig();
    } else {
        $status_msg = "\"$id\" does not exists";
        $logger->warn("$status_msg");
        return ($STATUS::NOT_FOUND, $status_msg);
    }

    $status_msg = "\"$id\" successfully deleted";
    $logger->info("$status_msg");
    return ($STATUS::OK, $status_msg);
}

sub read {
    my ($self, $id ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($status,$result_or_msg) = ($STATUS::OK,undef);
    my $conf = $self->loadConfig;

    if(exists $conf->{$id}) {
        my %values = ( id => $id, %{$conf->{$id}});
        $result_or_msg = \%values;
    }
    else {
        $status = $STATUS::NOT_FOUND;
        $result_or_msg = "\"$id\" does not exists";
    }
    return ($status,$result_or_msg);
}

=head2 read_all_names

=cut

sub read_all_names {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $conf = $self->loadConfig();
    my $tied_conf = tied(%$conf);

    return ($STATUS::OK, [$tied_conf->Sections()] );
}

sub read_all {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my @results;
    my $conf = $self->loadConfig();
    my $tied_conf = tied(%$conf);
    foreach my $id  ($tied_conf->Sections()) {
        my %values = ( id => $id, %{$conf->{$id}});
        push @results,\%values;
    }
    return ($STATUS::OK, \@results);
}

sub updateConfig {
    my ($self,$conf) = @_;
    $self->writeConfig();
}

=head2 writeConfig

=cut

sub writeConfig {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $conf = $self->loadConfig();
    my $config_file = $self->config_file;
    tied(%$conf)->WriteConfig($config_file)
        or $logger->logdie(
            "Unable to write config to $config_file. "
            ."You might want to check the file's permissions."
        );
}

=back

=head1 AUTHOR

James Jude Rouzier <jrouzier@inverse.ca>

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
