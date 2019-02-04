package pf::ConfigStore::SecurityEvents;

=head1 NAME

pf::ConfigStore::SecurityEvents

=cut

=head1 DESCRIPTION

pf::ConfigStore::SecurityEvents

=cut

use Moo;
use namespace::autoclean;
use pf::file_paths qw(
    $security_events_config_file
    $security_events_default_config_file
);

use pf::security_event_config;

extends 'pf::ConfigStore';

sub configFile { $security_events_config_file }

sub importConfigFile { $security_events_default_config_file };

sub pfconfigNamespace { 'config::SecurityEvents' }

sub default_section { 'defaults' }

=head1 Methods

=head2 remove

remove

=cut

sub remove {
    my ($self,$id,$security_event) = @_;
    return undef if (int($id) < 1500000);
    return $self->SUPER::remove($id,$security_event);
}

=head2 listTriggers

list all the triggers

=cut

sub listTriggers {
    my ($self) = @_;
    my ($trigger, %triggers);
    my $cachedConfig = $self->cachedConfig;
    foreach my $security_event ($cachedConfig->Sections()) {
        $trigger = $cachedConfig->val($security_event, 'trigger');
        if (defined($trigger)) {
            my @security_event_triggers = $self->split_list($trigger);
            @triggers{@security_event_triggers} = ();

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

Clean up security_event

=cut

sub cleanupAfterRead {
    my ($self, $id, $security_event) = @_;
    $self->expand_list($security_event, qw(actions whitelisted_roles));
    if($security_event->{user_mail_message} && ref($security_event->{user_mail_message}) eq 'ARRAY'){
        $security_event->{user_mail_message} = join("\n", @{$security_event->{user_mail_message}});
    }
    if ( exists $security_event->{window} ) {
        $security_event->{'window_dynamic'} = $security_event->{window};
    }
}

=head2 cleanupBeforeCommit

Clean data before update or creating

=cut

sub cleanupBeforeCommit {
    my ($self, $id, $security_event) = @_;
    $self->flatten_list($security_event, qw(actions trigger whitelisted_roles));
    if ($security_event->{'window_dynamic'}) {
        $security_event->{'window'} = 'dynamic';
    }
    delete $security_event->{'window_dynamic'};
}

sub commit {
    my ( $self ) = @_;
    my ($result,$msg) = $self->SUPER::commit();
    pf::security_event_config::loadSecurityEventsIntoDb();
    return ($result,$msg);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2018 Inverse inc.

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
