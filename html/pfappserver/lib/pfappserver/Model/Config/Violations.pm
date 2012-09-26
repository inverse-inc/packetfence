package pfappserver::Model::Config::Violations;

=head1 NAME

pfappserver::Model::Config::Violations - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=cut

use strict;
use warnings;

use Config::IniFiles;
use Moose;
use namespace::autoclean;
use Readonly;

use pf::config;
use pf::error qw(is_error is_success);
use pf::trigger qw(parse_triggers);

extends 'pfappserver::Model::Config::IniStyleBackend';

Readonly::Scalar our $params => ["actions", "auto_enable", "button_text", "desc", "enabled", "grace", "max_enable", "priority", "redirect_url", "snort_rules", "trigger", "url", "vlan", "whitelisted_categories", "window", "vclose"];
# window_dynamic?
Readonly::Scalar our $actions => { autoreg => 'Autoreg',
                                   close => 'Close',
                                   email => 'Email',
                                   log => 'Log',
                                   trap => 'Trap' };

sub _myConfigFile { return $conf_dir . "/violations.conf" };

=head1 METHODS

=over

=item availableActions

=cut

sub availableActions {
    my ($self) = @_;

    return $actions;
}

=item update

Update configuration. Supports batch updates.

$config_update_ref is an hashref with key section.param and the value as a
value, directly.

One value will update one parameter and multiple key => value pairs will
perform a batch update.

=cut
sub update {
    my ($self, $violation_update_ref) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    while (my ($violation_id, $violation_entry) = each %$violation_update_ref) {
        foreach my $param (@$params) {
            if ($param eq 'enabled'
                || $param eq 'auto_enable'
                || $param eq 'window_dynamic') {
                $violation_entry->{$param} = $violation_entry->{$param}? 'Y' : 'N';
            }
            my ($status, $result_ref) = $self->_update($violation_id,
                                                       $param, $violation_entry->{$param});
            # return errors to caller
            return ($status, $result_ref) if (is_error($status));
        }
    }

    # if it worked, let's write the config
    $self->_write_violations_conf();

    return ($STATUS::OK, "Successfully updated configuration");
}

=item _update

Updates a single value of the configuration tied hash. Meant to be called
internally. Does not write the configuration to disk!

=cut

sub _update {
    my ($self, $section, $param, $value) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $config_entry = "$section.$param";
    my $violations_conf = $self->_load_conf();

    if ( defined($violations_conf->{$section}->{$param}) ) {
        # a violations.conf parameter is unset: delete it
        if (!length($value)) {
            tied(%$violations_conf)->delval( $section, $param );
        }
        # a violations.conf parameter is replaced
        else {
            tied(%$violations_conf)->setval( $section, $param, $value );
        }
    }
    # violations.conf parameter isn't set: add to violations.conf
    else {
        tied(%$violations_conf)->newval( $section, $param, $value );
    }

    return ($STATUS::OK, "Successfully updated configuration");
}

=item _write_violations_conf

Performs the write of violations.conf.

=cut

sub _write_violations_conf {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $violations_conf = $self->_load_conf();
    tied(%$violations_conf)->WriteConfig($conf_dir . "/violations.conf")
        or $logger->logdie(
            "Unable to write config to $conf_dir/violations.conf. "
            ."You might want to check the file's permissions."
        );
}

=head2 read_violations

=cut

sub read_violations {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $violations_conf = $self->_load_conf();
    my @violations = ();
    foreach my $section ( keys %$violations_conf ) {
        push @violations, $section;
    }

    return ($STATUS::OK, \@violations);
}

=head2 read_value

=cut

sub read_value {
    my ( $self, $section, $param ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $status_msg;

    my $violations_conf = $self->_load_conf();

    # Warning: autovivification causes interfaces to be created if the section
    # is not looked on her own first when the file is written later.
    if (!defined($violations_conf->{$section}) || !defined($violations_conf->{$section}->{$param})) {
        $status_msg = "$section.$param does not exists";
        $logger->warn("$status_msg");
        return ($STATUS::NOT_FOUND, $status_msg);
    }

    $status_msg = $violations_conf->{$section}->{$param} || '';

    return ($STATUS::OK, $status_msg);    
}

=head2 read_violation

=cut

sub read_violation {
    my ( $self, $violation ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $violations_conf = $self->_load_conf();
    my @columns = pf::config::ui->instance->field_order('violationconfig get'); 
    my @resultset;

    foreach my $section ( keys %$violations_conf ) {
        if ( ($violation eq 'all') || ($violation eq $section) ) {
            my %values = ( id => $section );
            foreach my $column (@columns) {
                if ($violations_conf->{$section}->{$column}) {
                    if ($column eq 'actions' || $column eq 'trigger') {
                        my @items = split(',', $violations_conf->{$section}->{$column});
                        $values{$column} = \@items;
                    }
                    elsif ($column eq 'grace' || $column eq 'window') {
                        if (length($violations_conf->{$section}->{$column}) > 0) {
                            if ($violations_conf->{$section}->{$column} =~ m/(\d+)($TIME_MODIFIER_RE)/) {
                                my ($interval, $unit) = ($1, $2);
                                $values{$column} = { interval => $interval,
                                                     unit => $unit };
                            }
                            else {
                                $values{$column} = $violations_conf->{$section}->{$column};
                            }
                        }
                    }
                    else {
                        $values{$column} = $violations_conf->{$section}->{$column};
                    }
                }
                else {
                    $values{$column} = '';
                }
            }
            push @resultset, \%values;
        }
    }

    if ( $#resultset > -1 ) {
        return ($STATUS::OK, \@resultset);
    }
    else {
        return ($STATUS::NOT_FOUND, "Unknown violation $violation");
    }
}

=item delete_violation

Delete a violation section in the violations.conf configuration.

=cut
sub delete_violation {
    my ($self, $violation) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    return ($STATUS::FORBIDDEN, "This violation can't be deleted") if (int($violation) < 1500000);

    my $violations_conf = $self->_load_conf();
    my $tied_conf = tied(%$violations_conf);
    if ($tied_conf->SectionExists($violation)) {
        $tied_conf->DeleteSection($violation);
        $self->_write_violations_conf();
    }
    else {
        return ($STATUS::NOT_FOUND, "Violation not found");
    }

    return ($STATUS::OK, "Successfully deleted violation $violation");
}

=head2 list_triggers

=cut

sub list_triggers {
    my ($self) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my ($trigger, %triggers);

    my ($status, $violations) = $self->read_violations();
    if (is_success($status)) {
        foreach my $violation (@$violations) {
            ($status, $trigger) = $self->read_value($violation, 'trigger');
            if (is_success($status)) {
                my @items = split(',', $trigger);
                foreach $trigger (@items) {
                    $triggers{$trigger} = 1 unless (exists($triggers{$trigger}));
                }
            }
        }
    }

    my @list = sort keys %triggers;

    return \@list;
}

=head2 add_trigger

=cut

sub add_trigger {
    my ($self, $violation_id, $trigger) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my $triggers = '';
    my ($status, $result) = $self->read_value($violation_id, 'trigger');

    $logger->debug("Add trigger " . $trigger . " to violation " . $violation_id);

    if (is_success($status) && length($result) > 0) {
        my @items = split /\s*,\s*/, $result;
        if (grep $_ eq $trigger, @items) {
            return ($STATUS::OK, 'Trigger already included.');
        }
        else {
            my @sorted_items = sort (@items, $trigger);
            $triggers = join(',', @sorted_items);
        }
    }
    else {
        $triggers = $trigger;
    }

    ($status, $result) = $self->_update($violation_id, 'trigger', $triggers);
    if (is_error($status)) {
        return ($status, $result);
    }

    # if it worked, let's write the config
    $self->_write_violations_conf();

    return ($STATUS::OK, "Successfully added trigger to violation");
}

=head2 delete_trigger

=cut

sub delete_trigger {
    my ($self, $violation_id, $trigger) = @_;

    my $logger = Log::Log4perl::get_logger(__PACKAGE__);
    my $triggers = '';
    my ($status, $result) = $self->read_value($violation_id, 'trigger');

    $logger->debug("Remove trigger " . $trigger . " from violation " . $violation_id);

    if (is_success($status) && length($result) > 0) {
        my @items = split /\s*,\s*/, $result;
        if (grep $_ eq $trigger, @items) {
            my @sorted_items = sort grep { $_ ne $trigger } @items;
            $triggers = join(',', @sorted_items);
        }
        else {
            return ($STATUS::OK, 'Trigger already excluded.');
        }
    }

    ($status, $result) = $self->_update($violation_id, 'trigger', $triggers);
    if (is_error($status)) {
        return ($status, $result);
    }

    # if it worked, let's write the config
    $self->_write_violations_conf();

    return ($STATUS::OK, "Successfully deleted trigger from violation");
}

=head2 exists

=cut

sub exists {
    my ( $self, $violation ) = @_;
    my $logger = Log::Log4perl::get_logger(__PACKAGE__);

    my $violations_conf = $self->_load_conf();
    my $tied_conf = tied(%$violations_conf);

    return $TRUE if ( $tied_conf->SectionExists($violation) );
    return $FALSE;
}

=back

=head1 AUTHORS

Francis Lachapelle <flachapelle@inverse.ca>

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
