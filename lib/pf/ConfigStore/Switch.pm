package pf::ConfigStore::Switch;
=head1 NAME

pf::ConfigStore::Switch add documentation

=cut

=head1 DESCRIPTION

pf::ConfigStore::Switch;

=cut

use Moo;
use namespace::autoclean;
use pf::SwitchFactory;
use pf::log;
use HTTP::Status qw(:constants is_error is_success);

extends 'pf::ConfigStore';

sub _buildCachedConfig { $pf::SwitchFactory::switches_cached_config };

=head2 Methods

=over

=item cleanupAfterRead

Clean up switch data

=cut

sub cleanupAfterRead {
    my ( $self,$id, $switch ) = @_;
    my $logger = get_logger();

    if ($switch->{uplink} && $switch->{uplink} eq 'dynamic') {
        $switch->{uplink_dynamic} = 'dynamic';
        $switch->{uplink} = undef;
    }
    $self->expand_list($switch,'inlineTrigger');
    if (exists $switch->{inlineTrigger}) {
        $switch->{inlineTrigger} = [ map { _splitInlineTrigger($_) } @{$switch->{inlineTrigger}}  ];
    }
}

sub _splitInlineTrigger {
    my ($trigger) = @_;
    my ( $type, $value ) = split( /::/, $trigger );
    return { type=> $type,value => $value };
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
    if (exists $switch->{inlineTrigger}) {
        # Build string definition for inline triggers (see pf::vlan::isInlineTrigger)
        my $has_always;
        my @triggers = map { $has_always = 1 if $_->{type} eq 'always';  $_->{type} . '::' . ($_->{value} || '1') } @{$switch->{inlineTrigger}};
        @triggers = ('always::1') if $has_always;
        $switch->{inlineTrigger} = join(',', @triggers);
    }
}

=item remove

Delete an existing item

=cut

sub remove {
    my ($self,$id) = @_;
    if($id eq 'default') {
        return undef;
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

