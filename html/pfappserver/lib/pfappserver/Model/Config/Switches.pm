package pfappserver::Model::Config::Switches;

=head1 NAME

pfappserver::Model::Config::Switches - Catalyst Model

=head1 DESCRIPTION

Configuration module for operations involving conf/switches.conf.

=cut

use Moose;  # automatically turns on strict and warnings
use namespace::autoclean;
use Readonly;

use pf::config;
use pf::config::ui;
use pf::error qw(is_error is_success);

extends 'pfappserver::Model::Config::IniStyleBackend';

Readonly::Scalar our $NAME => 'Switches';

sub _getName        { return $NAME };
sub _myConfigFile   { return $pf::config::switches_config_file };


=head1 METHODS

=head2 MODEL CRUD OPERATORS

=over

=item read

Return an array of configured switches/network equipment (and their configurations) or only one if specified.

=cut
sub read {
    my ( $self, $switch ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($status, $result) = $self->readHash($switch);

    if (is_success($status)) {
        foreach my $switch (@$result) {
            if ($switch->{uplink} && $switch->{uplink} eq 'dynamic') {
                $switch->{uplink_dynamic} = 'dynamic';
                $switch->{uplink} = undef;
            }
            if ($switch->{triggerInline}) {
                # Decompose inline triggers (see pf::vlan::isInlineTrigger)
                my @triggers = ();
                foreach my $trigger (split(/,/, $switch->{triggerInline})) {
                    my ( $type, $value ) = split( /::/, $trigger );
                    $type = lc($type);
                    push(@triggers, { type => $type, value => $value });
                }
                $switch->{triggerInline} = \@triggers;
            }
        }
        my @switches = sort { $b->{id} cmp $a->{id} } @$result;
        $result = \@switches;
    }

    return ($status, $result);
}

=item update

Create or update an existing switch/network equipment.

=cut
sub update {
    my ( $self, $switch, $assignments ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    return ($STATUS::FORBIDDEN, "This method does not handle switch \"$switch\"")
        if ( $switch eq 'all' );

    my $switches_conf = $self->loadConfig;
    my $tied_conf = tied(%$switches_conf);

    if ($assignments->{uplink_dynamic}) {
        $assignments->{uplink} = 'dynamic';
        $assignments->{uplink_dynamic} = undef;
    }
    if ($assignments->{triggerInline}) {
        # Build string definition for inline triggers (see pf::vlan::isInlineTrigger)
        my @triggers = map { $_->{type} . '::' . ($_->{value} || '1') } @{$assignments->{triggerInline}};
        $assignments->{triggerInline} = join(',', @triggers);
    }

    while ( my ($param, $value) = each %$assignments ) {
        if ( defined( $switches_conf->{$switch}->{$param} ) ) {
            $tied_conf->setval( $switch, $param, $value );
        } else {
            $tied_conf->newval( $switch, $param, $value );
        }
    }
    $self->updateConfig(\%$switches_conf);

    $status_msg = "Switch \"$switch\" successfully modified";
    $logger->info("$status_msg");

    return ($STATUS::OK, $status_msg);
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
