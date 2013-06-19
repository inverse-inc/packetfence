package pf::ConfigStore::Violations;

=head1 NAME

pf::ConfigStore::Violations

=cut

=head1 DESCRIPTION

pf::ConfigStore::Violations

=cut

use Moo;
use namespace::autoclean;

use pf::violation_config;

extends 'pf::ConfigStore';

readViolationConfigFile();

sub _buildCachedConfig { $pf::violation_config::cached_violations_config };

=head1 Methods

=head2 remove

remove

=cut

sub remove {
    my ($self,$id,$violation) = @_;
    return undef if (int($id) < 1500000);
    return $self->SUPER::remove($id,$violation);
}

=head2 listTriggers

list all the triggers

=cut

sub listTriggers {
    my ($self) = @_;
    my ($trigger, %triggers);
    my $cachedConfig = $self->cachedConfig;
    foreach my $violation ($cachedConfig->Sections()) {
        $trigger = $cachedConfig->val($violation, 'trigger');
        if (defined($trigger)) {
            @triggers{$self->split_list($trigger)} = ();
        }
    }
    return [sort keys %triggers];
}


=head2 addTrigger

Added trigger to a list

=cut

sub addTrigger {
    my ($self, $id, $trigger) = @_;
    my $config = $self->cachedConfig;
    my $result;
    if($self->hasId($id)) {
        my $trigger_val = $config->val($id,'trigger');
        $result = 1;
        if ($trigger_val) {
            my %triggers_exists;
            @triggers_exists{ $self->split_list($trigger)  } = ();
            if (exists $triggers_exists{$trigger}) {
                $result = 2;
            } else {
                $config->setval(
                    $id, 'trigger',
                    $self->join_list(sort (keys %triggers_exists,$trigger))
                );
            }
        } else {
            $config->setval($id,'trigger',$trigger);
        }
    }
    return $result;
}

=head2 deleteTrigger

Delete trigger from a list

=cut

sub deleteTrigger {
    my ($self, $id, $trigger) = @_;
    my $config = $self->cachedConfig;
    my $result;
    if($self->hasId($id)) {
        my $trigger_val = $config->val($id,'trigger');
        $result = 1;
        if ($trigger_val) {
            my %triggers_exists;
            @triggers_exists{ $self->split_list($trigger) } = ();
            if (delete $triggers_exists{$trigger}) {
                $config->setval(
                    $id, 'trigger',
                    $self->join_list(sort keys %triggers_exists)
                );
            } else {
                $result = 2;
            }
        }
    }
    return $result;
}

=head2 cleanupAfterRead

Clean up violation

=cut

sub cleanupAfterRead {
    my ($self, $id, $violation) = @_;
    $self->expand_list($violation, qw(actions trigger whitelisted_categories));
    if ( exists $violation->{window} ) {
        $violation->{'window_dynamic'} = $violation->{window};
    }
}

=head2 cleanupBeforeCommit

Clean data before update or creating

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $violation) = @_;
    $self->flatten_list($violation, qw(actions trigger whitelisted_categories));
    if ($violation->{'window_dynamic'}) {
        $violation->{'window'} = 'dynamic';
    }
    delete $violation->{'window_dynamic'};
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

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
