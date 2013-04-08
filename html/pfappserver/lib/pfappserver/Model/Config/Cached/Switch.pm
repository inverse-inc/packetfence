package pfappserver::Model::Config::Cached::Switch;
=head1 NAME

pfappserver::Model::Config::Cached::Switch add documentation

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Cached::Switch;

=cut

use Moose;
use namespace::autoclean;
use pf::config::cached;
use pf::config;
use HTTP::Status qw(:constants is_error is_success);

extends 'pfappserver::Base::Model::Config::Cached';

has '+configFile' => (default => $pf::config::switches_config_file);

=head2 Methods

=over

=item cleanupAfterRead

Clean up switch data

=cut

sub cleanupAfterRead {
    my ( $self,$id, $switch ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

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

=item cleanupBeforeCommit

Clean data before update or creating

=cut

sub cleanupBeforeCommit {
    my ( $self, $id, $switch ) = @_;

    if ($switch->{uplink_dynamic}) {
        $switch->{uplink} = 'dynamic';
        $switch->{uplink_dynamic} = undef;
    }
    if ($switch->{triggerInline}) {
        # Build string definition for inline triggers (see pf::vlan::isInlineTrigger)
        my @triggers = map { $_->{type} . '::' . ($_->{value} || '1') } @{$switch->{triggerInline}};
        $switch->{triggerInline} = join(',', @triggers);
    }

}

=item remove

Delete an existing item

=cut

sub remove {
    my ($self,$id) = @_;
    if($id eq 'all') {
        return ($STATUS::INTERNAL_SERVER_ERROR, "Cannot delete this item");
    }
    return $self->SUPER::remove($id);
}

__PACKAGE__->meta->make_immutable;


=back

=head1 COPYRIGHT

Copyright (C) 2013 Inverse inc.

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

