package pf::Authentication::Source::LocalDBSource;

=head1 NAME

pf::Authentication::Source::LocalDBSource

=head1 DESCRIPTION

Authentication source for local database users (the C<password> / C<person>
tables), same credential store as the C<SQL> source.

Where C<SQLSource> overrides C<match> and reads the rights verbatim from the
user's row, this source keeps the rule engine: rights are assigned by rules whose
conditions can use the stored attributes of the local user on top of the common
PacketFence conditions.

When no rule matches, it falls back to the attributes stored on the user, the way
C<SQLSource> does, so that an administrator whose rights only come from their
account is not locked out. C<fallback_to_static_user_attributes> turns that off.

=cut

use strict;
use warnings;

use List::Util qw(none);

use pf::constants qw($TRUE $FALSE);
use pf::password;
use pf::person;
use pf::Authentication::constants;
use pf::constants::authentication::messages;
use pf::Authentication::Rule;
use pf::Authentication::Source;
use pf::Authentication::Source::SQLSource;
use pf::log;
use pf::util qw(isdisabled);

use Moose;
extends 'pf::Authentication::Source';
with qw(pf::Authentication::InternalRole);

has '+type' => (default => 'LocalDB');

# Assign the attributes stored on the user when no rule of the requested class matched
has 'fallback_to_static_user_attributes' => (is => 'rw', default => 1);

# User lookups, kept for the duration of one match
has '_user_lookup' => (is => 'rw', lazy => 1, default => sub { {} });

# Convenience selection - the condition editor also accepts free-text attributes
our @OWN_ATTRIBUTES = qw(
    pid
    firstname
    lastname
    email
    company
    title
    nickname
    notes
    telephone
    cell_phone
    work_phone
    custom_field_1
    custom_field_2
    custom_field_3
    custom_field_4
    custom_field_5
    custom_field_6
    custom_field_7
    custom_field_8
    custom_field_9
    category
    sponsor
    access_level
    unregdate
    expiration
);

=head1 METHODS

=head2 dynamic_routing_module

Which module to use for DynamicRouting

=cut

sub dynamic_routing_module { 'Authentication::Login' }

=head2 available_attributes

The common attributes plus the local user attributes rules can be written on.

=cut

sub available_attributes {
    my $self = shift;

    my $super_attributes = $self->SUPER::available_attributes;
    my $own_attributes = [ map { { value => $_, type => $Conditions::SUBSTRING } } @OWN_ATTRIBUTES ];

    return [@$super_attributes, @$own_attributes];
}

=head2 authenticate

Validate the credentials against the local C<password> table.

=cut

sub authenticate {
    my ($self, $username, $password) = @_;

    my $result = pf::password::validate_password($username, $password, 0);

    if ($result == $pf::password::AUTH_SUCCESS) {
        return ($TRUE, $AUTH_SUCCESS_MSG);
    } elsif ($result == $pf::password::AUTH_FAILED_EXPIRED) {
        return ($FALSE, $AUTH_PASSWD_EXPIRED);
    }

    return ($FALSE, $AUTH_FAIL_MSG);
}

=head2 password_entry

The row of the password table the request is about, C<undef> when the user is
unknown to the local database.

=cut

sub password_entry {
    my ($self, $params) = @_;
    my $cache = $self->_user_lookup;

    if ($params->{'username'}) {
        my $key = "password:$params->{'username'}";
        $cache->{$key} = pf::password::view($params->{'username'}) unless exists $cache->{$key};
        return $cache->{$key};
    }
    elsif ($params->{'email'}) {
        my $key = "password_email:$params->{'email'}";
        $cache->{$key} = pf::password::view_email($params->{'email'}) unless exists $cache->{$key};
        return $cache->{$key};
    }

    return undef;
}

=head2 person_entry

The row of the person table of a local user, cached like L</password_entry>.

=cut

sub person_entry {
    my ($self, $pid) = @_;
    my $cache = $self->_user_lookup;
    my $key = "person:$pid";

    $cache->{$key} = pf::person::person_view($pid) unless exists $cache->{$key};

    return $cache->{$key};
}

=head2 match

Rules first, and when none of them matched, the attributes stored on the user.

=cut

sub match {
    my ($self, $params, $action, $extra) = @_;

    $self->_user_lookup({});

    my ($rule, $ignore_action, $matched) = $self->SUPER::match($params, $action, $extra);
    if (my $warning = $self->unconditional_admin_rule_warning($rule)) {
        get_logger->warn($warning);
    }

    ($rule, $ignore_action, $matched) = $self->match_static_user_attributes($params, $action)
        unless defined $rule;

    $self->_user_lookup({});

    return ($rule, $ignore_action, $matched);
}

=head2 unconditional_admin_rule_warning

A catchall administration rule sets the access level of every local user, the
administrators included, and can therefore lock them out. Returns what to say
about such a rule, C<undef> otherwise.

=cut

sub unconditional_admin_rule_warning {
    my ($self, $rule) = @_;
    local $_;

    return undef unless defined $rule;
    return undef unless ($rule->{'class'} // '') eq $Rules::ADMIN;
    return undef if @{ $rule->{'conditions'} // [] };

    my ($access_level) = grep { $_->type eq $Actions::SET_ACCESS_LEVEL } @{ $rule->{'actions'} // [] };
    return undef unless $access_level;

    return "Rule (" . ($rule->{'id'} // '') . ") of source " . $self->id
        . " has no condition: it sets the access level '" . ($access_level->value // '')
        . "' for every user of the local database, administrators included";
}

=head2 match_static_user_attributes

Build a rule out of the attributes stored on the user, the way C<SQLSource> does,
for a user that matched no rule at all. Rules always take precedence, and this can
only grant what is stored on the user - it never revokes anything.

=cut

sub match_static_user_attributes {
    my ($self, $params, $action) = @_;
    local $_;

    # Only an explicit "off" counts: an object built by an older pfconfig has no value at all
    my $fallback = $self->fallback_to_static_user_attributes;
    return (undef, undef, undef) if defined $fallback && (!$fallback || isdisabled($fallback));

    my $password_entry = $self->password_entry($params);
    return (undef, undef, undef) unless defined $password_entry;

    my $rule_class = $params->{'rule_class'} // $Rules::AUTH;
    my $actions = pf::Authentication::Source::SQLSource->static_user_attribute_actions($password_entry);
    my @actions = grep { $_->class eq $rule_class } @$actions;
    return (undef, undef, undef) unless @actions;

    # Same action filtering as in pf::Authentication::Source::match
    if (defined $action) {
        my $allowed_actions = $Actions::ALLOWED_ACTIONS{$action} // {};
        return (undef, undef, undef) if none { $allowed_actions->{$_->type} } @actions;
    }

    get_logger->info(
        "No $rule_class rule matched in source " . $self->id
        . ", falling back to the static attributes stored on the user"
    );

    my $rule = pf::Authentication::Rule->new({
        id      => 'static_user_attributes',
        class   => $rule_class,
        match   => $Rules::ALL,
        actions => \@actions,
    });

    return ($rule, undef, $password_entry->{'pid'});
}

=head2 match_in_subclass

Confirm the user exists in the local database, then evaluate the source-specific
conditions against the user's stored C<person> / C<password> attributes.

=cut

sub match_in_subclass {
    my ($self, $params, $rule, $own_conditions, $matching_conditions) = @_;
    local $_;

    my $username = $params->{'username'} || $params->{'email'};
    return (undef, undef) unless defined $username && length $username;

    my $password_entry = $self->password_entry($params);
    return (undef, undef) unless defined $password_entry;

    my $pid = $password_entry->{'pid'} // $username;

    # What the conditions are matched against: the person columns plus the relevant password ones
    my %user_attrs;
    my $person = $self->person_entry($pid);
    if (ref($person) eq 'HASH') {
        %user_attrs = %$person;
    }
    for my $col (qw(category sponsor access_level unregdate expiration)) {
        $user_attrs{$col} = $password_entry->{$col} if defined $password_entry->{$col};
    }
    $user_attrs{'pid'} //= $pid;

    foreach my $condition (@{ $own_conditions }) {
        my $attribute = $condition->{'attribute'};
        if ($condition->matches($attribute, $user_attrs{$attribute}, $params)) {
            push(@{ $matching_conditions }, $condition);
        }
    }

    return ($pid, undef);
}

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2026 Inverse inc.

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

__PACKAGE__->meta->make_immutable unless $ENV{"PF_SKIP_MAKE_IMMUTABLE"};
1;

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:
