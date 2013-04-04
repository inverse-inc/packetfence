package pfappserver::Model::Config::Cached::Violations;
=head1 NAME

pfappserver::Model::Config::Cached::Profile add documentation

=cut

=head1 DESCRIPTION

pfappserver::Model::Config::Cached::Profile

=cut

use Moose;
use namespace::autoclean;
use pf::config::cached;
use pf::config;
use Readonly;

extends 'pfappserver::Base::Model::Config::Cached';

Readonly::Scalar our $actions => { autoreg => 'Autoreg',
                                   close => 'Close',
                                   email => 'Email',
                                   log => 'Log',
                                   trap => 'Trap' };

=head2 Methods

=over

=item _buildCachedConfig

=cut

sub _buildCachedConfig {
    my ($self) = @_;
    return pf::config::cached->new(-file => $pf::config::violations_config_file);
}

=item availableActions

=cut

sub availableActions {
    my $self = shift;

    return $actions;
}

=item availableTemplates

Return the list of available remediation templates

=cut

sub availableTemplates {
    opendir(DIR, $CAPTIVE_PORTAL{TEMPLATE_DIR} . '/violations');
    my @templates = grep { /^[^\.]+\.html$/ } readdir(DIR);
    s/\.html// for @templates;
    closedir(DIR);

    return \@templates;
}

=item remove

=cut

sub remove {
    my ($self,$id,$violation) = @_;
    return ($STATUS::FORBIDDEN, "This violation can't be deleted") if (int($id) < 1500000);
    return $self->SUPER::remove($id,$violation);
}

=item listTriggers

=cut

sub listTriggers {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ($trigger, %triggers);

    my $cachedConfig = $self->cachedConfig;
    foreach my $violation ($cachedConfig->Sections()) {
        $trigger = $cachedConfig->val($violation, 'trigger');
        if (defined($trigger)) {
            my @items = grep {!exists $triggers{$_}}  split(',', $trigger);
            @triggers{@items} = ();
        }
    }
    my @list = sort keys %triggers;
    return \@list;
}


=item addTrigger

=cut

sub addTrigger {
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my ( $self,$violation,$trigger ) = @_;
    if ($violation->{trigger}) {
        my %triggers_exists;
        @triggers_exists{@{$violation->{trigger}}} = ();
        if (exists $triggers_exists{$trigger}) {
            return ($STATUS::OK, 'Trigger already included.');
        }
        $violation->{trigger} = [sort (@{$violation->{trigger}},$trigger)];
    } else {
        $violation->{trigger} = [$trigger];
    }
    return ($STATUS::OK, "Successfully added trigger to violation");
}

=item deleteTrigger

=cut

sub deleteTrigger {
    my ( $self,$violation,$trigger ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    if ($violation->{trigger}) {
        my %triggers_exists;
        @triggers_exists{@{$violation->{trigger}}} = ();
        if (!exists $triggers_exists{$trigger}) {
            return ($STATUS::OK, 'Trigger already excluded.');
        }
        delete $triggers_exists{$trigger};
        $violation->{trigger} = [sort keys %triggers_exists];

    } else {
            return ($STATUS::OK, 'Trigger already excluded.');
    }

    return ($STATUS::OK, "Successfully deleted trigger from violation");
}

=item cleanupAfterRead

Clean up violation

=cut

sub cleanupAfterRead {
    my ( $self,$id, $violation ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    $self->expand_list($violation,qw(actions trigger));
    if ( exists $violation->{window} ) {
        $violation->{'window_dynamic'} = $violation->{window};
    }
}

=item cleanupBeforeCommit

Clean data before update or creating

=cut

sub cleanupBeforeCommit {
    my ( $self, $id, $violation ) = @_;
    $self->flatten_list($violation,qw(actions trigger));

    if ($violation->{'window_dynamic'}) {
        $violation->{'window'} = 'dynamic';
    }
    delete $violation->{'window_dynamic'};
}

=back

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

Minor parts of this file may have been contributed. See CREDITS.

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

Copyright (C) 2005 Kevin Amorin

Copyright (C) 2005 David LaPorte

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

